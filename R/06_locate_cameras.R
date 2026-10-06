# Assign each camera to the local agency whose area contains it: the city or town police department, or the
# county agency outside them. This is a geographic measure ("located"), not ownership.
#
# Cameras whose operator is classified private or public_other (05_classify_operators.R) are excluded:
# location in a city does not make a DOT, CHP, university or retailer camera the city PD's.
# Every remaining camera gets a status (located_status) saying how it was placed:
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
# Only current agencies receive cameras (not contract cities or historical ORIs; see 03_agencies.R).
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

ag <- ag_all |> filter(is_current(record_status))
n_log(ag, "agencies eligible for assignment (contract cities and historical ORIs dropped)")

source("R/name_parser.R")

# 1. Point-in-polygon ---------------------------------------------------------------------------------------
# Incorporated places (DC is FUNCSTAT N). C9 = cities TIGER keeps as inactive after a merger, cut out of the
# consolidated government's polygon; their police departments still carry those codes (Louisville Metro PD,
# 2148000; Houma PD, 2236255).
inc_places <- places |> filter(CLASSFP %in% c("C1", "C2", "C5", "C6", "C7", "C8", "C9"))
act_cousub <- cousubs |> filter(FUNCSTAT == "A")
pts <- st_as_sf(cams |> select(osm_id, lon, lat), coords = c("lon", "lat"), crs = 4326) |> st_transform(st_crs(places))
first_hit <- function(poly) {   # GEOID of the polygon containing each camera (polygons within a layer don't overlap)
  idx <- st_intersects(pts, poly)
  stopifnot(all(lengths(idx) <= 1))
  vapply(idx, \(j) if (length(j)) poly$GEOID[j] else NA_character_, "")
}
cams <- cams |> mutate(place_geoid = first_hit(inc_places), cousub_geoid = first_hit(act_cousub), county_geoid = first_hit(counties))
message("  in an incorporated place: ", sum(!is.na(cams$place_geoid)), "; in an active county subdivision: ",
        sum(!is.na(cams$cousub_geoid)), "; in no county: ", sum(is.na(cams$county_geoid)))

# 2. Place code -> PD -------------------------------------------------------------------------------------
cs_key <- function(g) paste0(substr(g, 1, 2), substr(g, 6, 10))   # cousub GEOID -> state + 5-digit code
squash <- function(x) str_to_lower(x) |> str_replace_all("\\b(the|of|by|on|in)\\b", " ") |> str_replace_all("[^a-z]", "")
MUNI_W <- "(city|town|village|township|borough)"
# does each place overlap the paired county (not just share a border)? Places can span counties; checked only
# for the few pairs needed.
in_county <- function(place, county) {
  p <- st_transform(st_geometry(inc_places)[match(place, inc_places$GEOID)], 5070)
  k <- st_transform(st_geometry(counties)[match(county, counties$GEOID)], 5070)
  vapply(seq_along(place), \(i) !is.na(place[i]) && !is.na(county[i]) &&
           lengths(st_relate(p[i], k[i], pattern = "2********")) > 0, TRUE)
}
# a county subdivision's county is in its GEOID
geo_names <- bind_rows(
  st_drop_geometry(inc_places) |>
    transmute(code = GEOID, geo_name = NAME, geo_lsad = NAMELSAD, layer = "place", geo_county = NA_character_, geo_pop = pop_acs),
  st_drop_geometry(act_cousub) |>
    transmute(code = cs_key(GEOID), geo_name = NAME, geo_lsad = NAMELSAD, layer = "cousub", geo_county = substr(GEOID, 1, 5), geo_pop = pop_acs)) |>
  distinct(code, .keep_all = TRUE) |>
  mutate(gkey = squash(basic(str_remove(geo_name, "\\s*\\(balance\\)"))),
         gkey_sq = squash(basic(str_remove(str_remove(geo_name, "\\s*\\(balance\\)"), paste0("(?i)\\s", MUNI_W, "$")))),
         geo_word = str_match(str_to_lower(geo_lsad), paste0("\\b", MUNI_W, "\\b"))[, 2])

# Does the PD's name match the Census name of its code? Exact comparison after dropping accents, spaces and the
# type word ("Lake in the Hills" = "Lake in the Hills"). A type word in the agency name that contradicts the Census
# entity (a "Town" PD for a city polygon) does not count as matching.
name_check <- function(d) d |> select(-any_of(c("geo_name", "geo_county", "geo_pop", "layer", "gkey", "gkey_sq", "geo_word"))) |>
  left_join(geo_names |> select(code, geo_name, geo_county, geo_pop, layer, gkey, gkey_sq, geo_word), by = c("place_fips" = "code")) |>
  mutate(name_matches_code = (squash(akey) == gkey | squash(akey) == gkey_sq) &
           (is.na(agency_word) | is.na(geo_word) | agency_word == geo_word | str_detect(str_to_lower(geo_name), coalesce(agency_word, "\\x00"))))

muni_all <- ag |> filter(agency_type == "Municipal police") |>
  mutate(akey = parse_name(name)$core2,
         agency_word = str_match(str_to_lower(name), paste0("\\b", MUNI_W, "\\b"))[, 2])
muni <- muni_all |> filter(!is.na(place_fips), place_fips %in% geo_names$code) |> mutate(place_source = "leaic") |> name_check()
message("Municipal PDs (current): ", nrow(muni_all), "; LEAIC code found in TIGER ", TIGER_YEAR, ": ", nrow(muni))

# fallback: PDs with no usable LEAIC code -> exact name match to a TIGER incorporated place that is unique in the
# state and lies in the PD's county (when the PD's county is known)
pl_names <- st_drop_geometry(inc_places) |>
  transmute(GEOID, STATEFP, pkey = basic(str_remove(NAME, "\\s*\\(balance\\)"))) |>
  add_count(STATEFP, pkey, name = "n_pl") |> filter(n_pl == 1)
nm <- muni_all |> filter(!ori %in% muni$ori) |> mutate(STATEFP = STATES$fips[match(state, STATES$abbr)]) |>
  add_count(STATEFP, akey, name = "n_ag") |> filter(n_ag == 1) |>
  inner_join(pl_names, by = c("STATEFP", "akey" = "pkey")) |>
  filter(!GEOID %in% muni$place_fips, is.na(county_fips) | in_county(GEOID, county_fips))
message("  + matched by exact unique name to a ", TIGER_YEAR, " place in the same county (flagged): ", nrow(nm))
write_csv(nm |> select(ori, name, state, matched_place_geoid = GEOID), file.path(REVIEW, "located_pd_place_name_matches.csv"))
muni <- bind_rows(muni, nm |> mutate(place_fips = GEOID, place_source = "name_match_tiger") |> select(names(muni_all), place_source)) |>
  name_check()

# Wisconsin village PDs are often coded in LEAIC to the same-named town (county subdivision) next to the village
# (Germantown PD: the town of Germantown, population about 250, not the village of 20,000). A PD's code moves
# from a town to a same-named incorporated place when the place
#   - touches the town's county and has no PD of its own,
#   - lies outside the town (in New York a village lies inside its town, and the town PD already covers it),
#   - is closer in population to the PD's population served than the town is,
# and the PD's name doesn't say "Town" or "Township". A PD whose population fits town and place together better
# than the place alone keeps the town and gets the place as well (Bloomfield, WI).
place_inside_town <- function(place, town_code) {
  p <- st_point_on_surface(st_transform(st_geometry(inc_places)[match(place, inc_places$GEOID)], 5070))
  t <- st_transform(st_geometry(act_cousub)[match(town_code, cs_key(act_cousub$GEOID))], 5070)
  vapply(seq_along(place), \(i) lengths(st_within(p[i], t[i])) > 0, TRUE)
}
same_name_place <- geo_names |> filter(layer == "place") |>
  transmute(st = substr(code, 1, 2), gkey_sq, place_code = code, place_pop = geo_pop)
moved <- muni |> filter(layer == "cousub", !agency_word %in% c("town", "township"), coalesce(population_fbi, 0) > 0) |>
  mutate(st = substr(place_fips, 1, 2)) |>
  inner_join(same_name_place, by = c("st", "gkey_sq"), relationship = "many-to-many") |>
  filter(!place_code %in% muni$place_fips, !is.na(place_pop), !is.na(geo_pop),
         abs(population_fbi - place_pop) < abs(population_fbi - geo_pop)) |>
  filter(in_county(place_code, geo_county), !place_inside_town(place_code, place_fips)) |>
  distinct(ori, .keep_all = TRUE)
moved <- moved |> mutate(both = abs(population_fbi - (place_pop + geo_pop)) < abs(population_fbi - place_pop))
message("  PD codes moved from a town to the same-named place it serves: ", sum(!moved$both),
        "; place added to the town code: ", sum(moved$both))
write_csv(moved |> select(ori, name, state, town_code = place_fips, town_pop = geo_pop, place_code, place_pop, population_fbi, both),
          file.path(REVIEW, "located_pd_codes_moved_town_to_place.csv"))
muni <- muni |> left_join(moved |> filter(!both) |> select(ori, place_code), by = "ori") |>
  mutate(place_source = if_else(is.na(place_code), place_source, "town_code_moved_to_place"),
         place_fips = coalesce(place_code, place_fips)) |> select(-place_code)
muni <- bind_rows(muni, muni |> inner_join(moved |> filter(both) |> select(ori, place_code), by = "ori") |>
                    mutate(place_fips = place_code, place_source = "place_added_to_town_code") |> select(-place_code)) |>
  name_check()

# resolve codes shared by several PDs by name only
shared <- muni |> add_count(place_fips, name = "n_code") |> filter(n_code > 1)
resolved_shared <- shared |> filter(coalesce(name_matches_code, FALSE)) |> add_count(place_fips, name = "n_match") |> filter(n_match == 1)
unresolved_codes <- setdiff(unique(shared$place_fips), resolved_shared$place_fips)
message("Place codes shared by >1 PD: ", n_distinct(shared$place_fips), "; resolved by name: ",
        nrow(resolved_shared), "; left unresolved: ", length(unresolved_codes))
write_csv(shared |> mutate(resolution = case_when(ori %in% resolved_shared$ori ~ "assigned (name matches code)",
                                                  place_fips %in% unresolved_codes ~ "unresolved",
                                                  TRUE ~ "not assigned (name does not match code)")) |>
            select(place_fips, geo_name, ori, name, population_fbi, resolution) |> arrange(place_fips),
          file.path(REVIEW, "located_places_with_multiple_pds.csv"))
place_to_pd <- bind_rows(muni |> add_count(place_fips, name = "n_code") |> filter(n_code == 1),
                         resolved_shared) |> transmute(geo = place_fips, pd_ori = ori, pd_name_ok = coalesce(name_matches_code, FALSE))
stopifnot(!anyDuplicated(place_to_pd$geo))
# codes actually used for each PD (agencies.csv reports these, not the raw LEAIC codes)
saveRDS(muni |> filter(place_fips %in% place_to_pd$geo, ori %in% place_to_pd$pd_ori) |>
          summarise(place_used = paste(sort(unique(place_fips)), collapse = ";"), place_source = first(place_source), .by = ori),
        file.path(PROC, "pd_place_codes.rds"))
message("  single-PD codes whose PD name does not match the Census name (kept, flagged): ",
        sum(!coalesce(muni$name_matches_code[!muni$place_fips %in% shared$place_fips], FALSE)))
write_csv(muni |> filter(!coalesce(name_matches_code, FALSE)) |> select(ori, name, state, place_fips, geo_name, place_source),
          file.path(REVIEW, "located_pd_code_name_mismatches.csv"))

# 3. County -> county agency; county-wide PDs ------------------------------------------------------------
# Where a county has more than one sheriff / county police agency, the one with the larger FBI population wins;
# on a tie (both often 0), the sheriff.
cty <- ag |> filter(agency_type != "Municipal police", !is.na(county_fips))
multi_cty <- cty |> count(county_fips) |> filter(n > 1)
message("Counties with >1 sheriff/county police agency (largest FBI population kept): ", nrow(multi_cty))
write_csv(cty |> semi_join(multi_cty, by = "county_fips") |> select(county_fips, ori, name, agency_type, population_fbi) |>
            arrange(county_fips, desc(population_fbi)), file.path(REVIEW, "located_counties_with_multiple_county_agencies.csv"))
county_to_ag <- cty |> arrange(county_fips, desc(coalesce(population_fbi, -1)), agency_type != "Sheriff") |>
  distinct(county_fips, .keep_all = TRUE) |> select(geo = county_fips, cty_ori = ori)

# A municipal PD serving at least half its county's population is the county-wide fallback (consolidated
# governments; counties with no county agency). A PD whose place doesn't touch its LEAIC county is skipped
# (PAPEP0000, Philadelphia PD, carries Indiana County's code in LEAIC).
cty_pop <- st_drop_geometry(counties) |> select(county_fips = GEOID, county_pop = pop_acs)
cw <- muni_all |> filter(!is.na(county_fips)) |> left_join(cty_pop, by = "county_fips") |>
  filter(population_fbi >= 0.5 * county_pop) |>
  left_join(muni |> select(ori, code = place_fips, layer, geo_county), by = "ori") |>
  filter(is.na(code) | (layer == "place" & in_county(code, county_fips)) | (layer == "cousub" & geo_county == county_fips)) |>
  arrange(county_fips, desc(population_fbi)) |> distinct(county_fips, .keep_all = TRUE)
write_csv(cw |> select(county_fips, ori, name, population_fbi, county_pop), file.path(REVIEW, "located_countywide_pds.csv"))
countywide <- cw |> select(geo = county_fips, cw_ori = ori)
c8 <- inc_places$GEOID[inc_places$CLASSFP == "C8"]

# 4. Assign ------------------------------------------------------------------------------------------------
b <- cams |> select(osm_id, op_class, place_geoid, cousub_geoid, county_geoid) |>
  mutate(cousub_key = if_else(is.na(cousub_geoid), NA, cs_key(cousub_geoid)))
b <- b |> left_join(place_to_pd, by = c("place_geoid" = "geo")); n_log(b, "after place -> PD join")
b <- b |> left_join(place_to_pd |> rename(cs_pd_ori = pd_ori, cs_name_ok = pd_name_ok), by = c("cousub_key" = "geo")); n_log(b, "after county subdivision -> PD join")
b <- b |> left_join(county_to_ag, by = c("county_geoid" = "geo")); n_log(b, "after county -> county agency join")
b <- b |> left_join(countywide, by = c("county_geoid" = "geo")); n_log(b, "after county-wide PD join")
stopifnot(nrow(b) == nrow(cams))

b <- b |> mutate(
  located_status = case_when(
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
  located_ori = case_when(str_starts(located_status, "direct_place") ~ pd_ori, str_starts(located_status, "direct_cousub") ~ cs_pd_ori,
                          located_status %in% c("county_unincorporated", "inferred_no_pd_in_place") ~ cty_ori,
                          located_status == "inferred_countywide_pd" ~ cw_ori, TRUE ~ NA))
message("\nLocated status:"); print(count(b, located_status, sort = TRUE))
stopifnot(all(b$located_ori %in% c(NA, ag$ori)))
saveRDS(b |> select(osm_id, located_status, located_ori, place_geoid, cousub_geoid, county_geoid),
        file.path(PROC, "camera_location.rds"))
write_csv(cams |> filter(op_class %in% c("private", "public_other")) |> count(op_class, operator, sort = TRUE),
          file.path(REVIEW, "located_excluded_operators.csv"))
