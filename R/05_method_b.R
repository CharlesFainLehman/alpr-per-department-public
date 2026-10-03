# Method B: cameras LOCATED in each agency's area (a geographic measure, not ownership).
#
# Cameras whose operator is classified private or public_other (04b_operator_class.R) are excluded:
# location in a city does not make a DOT, CHP, university or retailer camera the city PD's.
# Every remaining camera gets a status (b_status) saying how it was placed:
#
#   direct_place            inside an incorporated place whose code identifies one current municipal PD
#   direct_cousub           inside an active town/township (county subdivision) with its own PD
#   direct_*_name_mismatch  as above, but the PD's name differs from the Census name of its code
#                           (often spelling: Middleboro/Middleborough; sometimes a wrong code) -- review
#   county_unincorporated   outside any incorporated place -> the county agency
#   inferred_no_pd_in_place inside a city with no PD in the agency list (often a sheriff contract city)
#                           -> county agency; inferred, not verified
#   inferred_countywide_pd  consolidated government with no place-level PD, or county with no county
#                           agency, where one municipal PD serves >= 50% of county population; inferred
#   unresolved_shared_code  place code shared by >1 PD and no unique name match; not assigned
#   no_local_agency         no local agency for the area (state-police areas); not assigned
#   excluded_private / excluded_public_other
#
# Place codes come from LEAIC (2012). Where several PDs share a code, the PD whose name matches the
# Census place name wins; otherwise the code is left unresolved (no population tie-break).
# Historical ORIs (record_status == "historical") never receive cameras.
source("R/00_setup.R")

cams     <- readRDS(file.path(PROC, "osm_alpr.rds"))
ag_all   <- readRDS(file.path(PROC, "agencies.rds"))
cls      <- readRDS(file.path(PROC, "operator_class.rds"))
places   <- readRDS(file.path(PROC, "places.rds"))
cousubs  <- readRDS(file.path(PROC, "cousubs.rds"))
counties <- readRDS(file.path(PROC, "counties.rds"))
n_log(cams, "cameras in")
cams <- cams |> left_join(cls, by = "osm_id")
n_log(cams, "cameras after joining operator class")
stopifnot(!anyNA(cams$op_class))

ag <- ag_all |> filter(record_status != "historical")
n_log(ag, "agencies eligible for assignment (historical ORIs dropped)")

# Name normalizer shared with method A
src <- readLines("R/04_method_a.R")
eval(parse(text = src[grep("^basic <- function", src):(grep("^# Agency side", src) - 1)]))

# 1. Point-in-polygon, keeping the number of candidate polygons -----------------------------------------
inc_places <- places |> filter(CLASSFP %in% c("C1", "C2", "C5", "C6", "C7", "C8"))   # incorporated; DC is FUNCSTAT N
act_cousub <- cousubs |> filter(FUNCSTAT == "A")
pts <- st_as_sf(cams |> select(osm_id, lon, lat), coords = c("lon", "lat"), crs = 4326) |> st_transform(st_crs(places))
hits <- function(poly, col) {
  idx <- st_intersects(pts, poly)
  list(first = vapply(idx, \(j) if (length(j)) poly[[col]][j[1]] else NA_character_, ""), n = lengths(idx))
}
hp <- hits(inc_places, "GEOID"); hc <- hits(act_cousub, "GEOID"); hk <- hits(counties, "GEOID")
cams <- cams |> mutate(place_geoid = hp$first, cousub_geoid = hc$first, county_geoid = hk$first,
                       n_polygon_overlaps = pmax(hp$n, 1) - 1 + pmax(hc$n, 1) - 1 + pmax(hk$n, 1) - 1)
message("  cameras in >1 candidate polygon of the same layer (first kept, flagged): ", sum(cams$n_polygon_overlaps > 0))
message("  in an incorporated place: ", sum(!is.na(cams$place_geoid)), "; in an active county subdivision: ",
        sum(!is.na(cams$cousub_geoid)), "; in no county: ", sum(is.na(cams$county_geoid)))

# 2. Place code -> PD -------------------------------------------------------------------------------------
cs_key <- function(g) paste0(substr(g, 1, 2), substr(g, 6, 10))   # cousub GEOID -> state + 5-digit code
squash <- function(x) iconv(x, "UTF-8", "ASCII//TRANSLIT") |> str_to_lower() |>
  str_replace_all("\\b(the|of|by|on|in)\\b", " ") |> str_replace_all("[^a-z]", "")
MUNI_W <- "(city|town|village|township|borough)"
geo_names <- bind_rows(
  st_drop_geometry(inc_places) |> transmute(code = GEOID, geo_name = NAME, geo_lsad = NAMELSAD, layer = "place"),
  st_drop_geometry(act_cousub) |> transmute(code = cs_key(GEOID), geo_name = NAME, geo_lsad = NAMELSAD, layer = "cousub")) |>
  distinct(code, .keep_all = TRUE) |>
  mutate(gkey = squash(basic(str_remove(geo_name, "\\s*\\(balance\\)"))),
         geo_word = str_match(str_to_lower(geo_lsad), paste0("\\b", MUNI_W, "\\b"))[, 2])

muni_all <- ag |> filter(agency_type == "Municipal police") |>
  mutate(akey = parse_name(name)$core2,
         agency_word = str_match(str_to_lower(name), paste0("\\b", MUNI_W, "\\b"))[, 2])
muni <- muni_all |> filter(!is.na(place_fips), place_fips %in% geo_names$code) |> mutate(place_source = "leaic")
message("Municipal PDs (current): ", nrow(muni_all), "; LEAIC code found in TIGER ", TIGER_YEAR, ": ", nrow(muni))

# fallback: PDs with no usable LEAIC code -> exact unique name match to a TIGER incorporated place
pl_names <- st_drop_geometry(inc_places) |>
  transmute(GEOID, STATEFP, pkey = basic(str_remove(NAME, "\\s*\\(balance\\)"))) |>
  add_count(STATEFP, pkey, name = "n_pl") |> filter(n_pl == 1)
nm <- muni_all |> filter(!ori %in% muni$ori) |> mutate(STATEFP = STATES$fips[match(state, STATES$abbr)]) |>
  add_count(STATEFP, akey, name = "n_ag") |> filter(n_ag == 1) |>
  inner_join(pl_names, by = c("STATEFP", "akey" = "pkey")) |> filter(!GEOID %in% muni$place_fips)
message("  + matched by exact unique name to a ", TIGER_YEAR, " place (flagged): ", nrow(nm))
write_csv(nm |> select(ori, name, state, matched_place_geoid = GEOID), file.path(OUT, "method_b_pd_place_name_matches.csv"))
muni <- bind_rows(muni, nm |> mutate(place_fips = GEOID, place_source = "name_match_tiger") |> select(names(muni)))

# check the PD name against the Census name of its code; resolve shared codes by name only
# Exact comparison after dropping accents, spaces and the type word; "Lake in the Hills" = "Lake in the Hills".
# Agency names that carry a type word contradicting the Census entity (a "Town" PD for a city polygon)
# do not count as matching it.
muni <- muni |> left_join(geo_names |> select(code, geo_name, gkey, geo_word), by = c("place_fips" = "code")) |>
  mutate(akey_sq = squash(akey),
         gkey_sq = squash(basic(str_remove(str_remove(geo_name, "\\s*\\(balance\\)"), paste0("(?i)\\s", MUNI_W, "$")))),
         name_matches_code = (akey_sq == gkey | akey_sq == gkey_sq) &
           (is.na(agency_word) | is.na(geo_word) | agency_word == geo_word | str_detect(str_to_lower(geo_name), coalesce(agency_word, "\\x00"))))
shared <- muni |> add_count(place_fips, name = "n_code") |> filter(n_code > 1)
resolved_shared <- shared |> filter(coalesce(name_matches_code, FALSE)) |> add_count(place_fips, name = "n_match") |> filter(n_match == 1)
unresolved_codes <- setdiff(unique(shared$place_fips), resolved_shared$place_fips)
message("Place codes shared by >1 PD: ", n_distinct(shared$place_fips), "; resolved by name: ",
        nrow(resolved_shared), "; left unresolved: ", length(unresolved_codes))
write_csv(shared |> mutate(resolution = case_when(ori %in% resolved_shared$ori ~ "assigned (name matches code)",
                                                  place_fips %in% unresolved_codes ~ "unresolved",
                                                  TRUE ~ "not assigned (name does not match code)")) |>
            select(place_fips, geo_name, ori, name, population_fbi, resolution) |> arrange(place_fips),
          file.path(OUT, "method_b_places_with_multiple_pds.csv"))
place_to_pd <- bind_rows(muni |> add_count(place_fips, name = "n_code") |> filter(n_code == 1),
                         resolved_shared) |> transmute(geo = place_fips, pd_ori = ori, pd_name_ok = coalesce(name_matches_code, FALSE))
stopifnot(!anyDuplicated(place_to_pd$geo))
message("  single-PD codes whose PD name does not match the Census name (kept, flagged): ",
        sum(!coalesce(muni$name_matches_code[!muni$place_fips %in% shared$place_fips], FALSE)))
write_csv(muni |> filter(!coalesce(name_matches_code, FALSE)) |> select(ori, name, state, place_fips, geo_name, place_source),
          file.path(OUT, "method_b_pd_code_name_mismatches.csv"))

# 3. County -> county agency; county-wide PDs ------------------------------------------------------------
cty <- ag |> filter(agency_type != "Municipal police", !is.na(county_fips))
multi_cty <- cty |> count(county_fips) |> filter(n > 1)
message("Counties with >1 sheriff/county police agency (largest FBI population kept): ", nrow(multi_cty))
write_csv(cty |> semi_join(multi_cty, by = "county_fips") |> select(county_fips, ori, name, agency_type, population_fbi) |>
            arrange(county_fips, desc(population_fbi)), file.path(OUT, "method_b_counties_with_multiple_county_agencies.csv"))
county_to_ag <- cty |> arrange(county_fips, desc(coalesce(population_fbi, -1))) |> distinct(county_fips, .keep_all = TRUE) |>
  select(geo = county_fips, cty_ori = ori)

cty_pop <- st_drop_geometry(counties) |> select(county_fips = GEOID, county_pop = pop_acs)
cw <- muni_all |> filter(!is.na(county_fips)) |> left_join(cty_pop, by = "county_fips") |>
  filter(population_fbi >= 0.5 * county_pop) |> arrange(county_fips, desc(population_fbi)) |> distinct(county_fips, .keep_all = TRUE)
write_csv(cw |> select(county_fips, ori, name, population_fbi, county_pop), file.path(OUT, "method_b_countywide_pds.csv"))
countywide <- cw |> select(geo = county_fips, cw_ori = ori)
c8 <- inc_places$GEOID[inc_places$CLASSFP == "C8"]

# 4. Assign ------------------------------------------------------------------------------------------------
b <- cams |> select(osm_id, op_class, place_geoid, cousub_geoid, county_geoid, n_polygon_overlaps) |>
  mutate(cousub_key = if_else(is.na(cousub_geoid), NA, cs_key(cousub_geoid)))
b <- b |> left_join(place_to_pd, by = c("place_geoid" = "geo")); n_log(b, "after place -> PD join")
b <- b |> left_join(place_to_pd |> rename(cs_pd_ori = pd_ori, cs_name_ok = pd_name_ok), by = c("cousub_key" = "geo")); n_log(b, "after county subdivision -> PD join")
b <- b |> left_join(county_to_ag, by = c("county_geoid" = "geo")); n_log(b, "after county -> county agency join")
b <- b |> left_join(countywide, by = c("county_geoid" = "geo")); n_log(b, "after county-wide PD join")
stopifnot(nrow(b) == nrow(cams))

b <- b |> mutate(
  b_status = case_when(
    op_class == "private" ~ "excluded_private",
    op_class == "public_other" ~ "excluded_public_other",
    !is.na(pd_ori) & pd_name_ok ~ "direct_place",
    !is.na(pd_ori) ~ "direct_place_name_mismatch",
    place_geoid %in% unresolved_codes ~ "unresolved_shared_code",
    !is.na(cs_pd_ori) & cs_name_ok ~ "direct_cousub",
    !is.na(cs_pd_ori) ~ "direct_cousub_name_mismatch",
    cousub_key %in% unresolved_codes ~ "unresolved_shared_code",
    place_geoid %in% c8 & !is.na(cw_ori) ~ "inferred_countywide_pd",
    is.na(cty_ori) & !is.na(cw_ori) ~ "inferred_countywide_pd",
    !is.na(place_geoid) & !is.na(cty_ori) ~ "inferred_no_pd_in_place",
    !is.na(cty_ori) ~ "county_unincorporated",
    TRUE ~ "no_local_agency"),
  b_ori = case_when(str_starts(b_status, "direct_place") ~ pd_ori, str_starts(b_status, "direct_cousub") ~ cs_pd_ori,
                    b_status %in% c("county_unincorporated", "inferred_no_pd_in_place") ~ cty_ori,
                    b_status == "inferred_countywide_pd" ~ cw_ori, TRUE ~ NA),
  b_excluded = str_starts(b_status, "excluded"))
message("\nMethod B status:"); print(count(b, b_status, sort = TRUE))
stopifnot(all(b$b_ori %in% c(NA, ag$ori)))
saveRDS(b |> select(osm_id, b_excluded, b_status, b_ori, place_geoid, cousub_geoid, county_geoid, n_polygon_overlaps),
        file.path(PROC, "method_b.rds"))
write_csv(cams |> filter(op_class %in% c("private", "public_other")) |> count(op_class, operator, sort = TRUE),
          file.path(OUT, "method_b_excluded_operators.csv"))

# 5. Agency geography status (lets agencies.csv separate "zero mapped" from "no usable geography") --------
geo_status <- ag_all |> transmute(ori, agency_type, record_status) |>
  mutate(geo_status = case_when(
    record_status == "historical" ~ "historical_record_not_assigned",
    agency_type == "Municipal police" & ori %in% place_to_pd$pd_ori ~ "place_code_resolved",
    agency_type == "Municipal police" & ori %in% shared$ori ~ "place_code_shared_not_assigned",
    agency_type == "Municipal police" & ori %in% cw$ori ~ "countywide_only",
    agency_type == "Municipal police" ~ "no_usable_place_code",
    ori %in% county_to_ag$cty_ori ~ "county_code_resolved",
    ori %in% cty$ori ~ "county_shared_other_agency_assigned",
    TRUE ~ "no_county_code"))
print(count(geo_status, geo_status, sort = TRUE))
saveRDS(geo_status |> select(ori, geo_status), file.path(PROC, "agency_geo_status.rds"))
