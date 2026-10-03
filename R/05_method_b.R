# Method B: spatial join. Camera -> incorporated place -> municipal PD;
#           otherwise -> county -> sheriff (or county police where it serves the unincorporated area).
#
# Order of assignment for each (non-private) camera:
#   1. Inside an active incorporated place (TIGER CLASSFP C*, FUNCSTAT A/B/F) whose FIPS code is
#      the LEAIC place code of a municipal PD                                   -> that PD
#   2. Inside an active county subdivision (towns/townships, FUNCSTAT A) whose FIPS code is the
#      LEAIC place code of a municipal PD (NJ/PA/MI/NY... township police)      -> that PD
#      (Not in the original spec. Without it, cameras in township-policed areas fall to the sheriff.
#       Kept separate in column b_level so the strict place/county version can be recovered.)
#   3. Otherwise                                                                -> county agency
#      (the Sheriff or County police with the largest FBI population served in that county).
# Census places that are CDPs, military, or inactive count as unincorporated.
source("R/00_setup.R")

cams     <- readRDS(file.path(PROC, "osm_alpr.rds"))
ag       <- readRDS(file.path(PROC, "agencies.rds"))       # needs LEAIC (03_agencies.R)
places   <- readRDS(file.path(PROC, "places.rds"))
cousubs  <- readRDS(file.path(PROC, "cousubs.rds"))
counties <- readRDS(file.path(PROC, "counties.rds"))
n_log(cams, "cameras in")

# 1. Exclude private cameras ------------------------------------------------------------------------
PRIVATE_OP_TYPES <- c("private", "business", "university", "school", "religious", "community", "hoa")
PRIVATE_OP_RX <- regex(paste0(
  "\\b(hoa|homeowners?|home owners?|property owners|owners association|condominium|condo|apartments?|",
  "residences|community association|poa|llc|inc|corp|corporation|company|plaza|mall|shopping|",
  "retail|store|stores|lowe'?s|home depot|walmart|wal-mart|target|kroger|costco|sam'?s club|",
  "simon property|casino|casinos|resort|hotel|fedex|ups|amazon|school|schools|academy|isd|",
  "school district|university|college|campus|hospital|medical|health|church|parish church)\\b"),
  ignore_case = TRUE)

cams <- cams |> mutate(
  excl_surveillance_private = coalesce(str_to_lower(surveillance) == "private", FALSE),
  excl_operator_type = coalesce(str_to_lower(operator_type) %in% PRIVATE_OP_TYPES, FALSE),
  excl_operator_text = coalesce(str_detect(operator, PRIVATE_OP_RX), FALSE) &
                       !coalesce(str_detect(operator, regex("police|sheriff", ignore_case = TRUE)), FALSE),
  b_excluded = excl_surveillance_private | excl_operator_type | excl_operator_text)
message("Excluded from method B as private: ", sum(cams$b_excluded), " of ", nrow(cams))
message("  surveillance=private: ", sum(cams$excl_surveillance_private),
        "; operator:type private/business/school etc.: ", sum(cams$excl_operator_type),
        "; operator name looks private: ", sum(cams$excl_operator_text))
write_csv(cams |> filter(b_excluded) |> count(operator, operator_type, surveillance, sort = TRUE),
          file.path(OUT, "method_b_excluded_private_operators.csv"))

# 2. Point-in-polygon ---------------------------------------------------------------------------------
pts <- st_as_sf(cams |> select(osm_id, lon, lat), coords = c("lon", "lat"), crs = 4326) |> st_transform(st_crs(places))
first_hit <- function(pts, poly, col) {
  idx <- st_intersects(pts, poly)
  nh <- lengths(idx)
  if (any(nh > 1)) message(sprintf("  %d cameras fall in >1 %s polygon (first kept)", sum(nh > 1), col))
  vapply(idx, \(j) if (length(j)) poly[[col]][j[1]] else NA_character_, "")
}
# Incorporated places of every class except C9 (inactive). Includes FUNCSTAT N: Washington, DC is
# flagged "nonfunctioning" because its government sits at the state/county level.
inc_places <- places |> filter(CLASSFP %in% c("C1", "C2", "C5", "C6", "C7", "C8"))
act_cousub <- cousubs |> filter(FUNCSTAT == "A")
cams$place_geoid  <- first_hit(pts, inc_places, "GEOID")
cams$cousub_geoid <- first_hit(pts, act_cousub, "GEOID")
cams$county_geoid <- first_hit(pts, counties, "GEOID")
message("  in an incorporated place: ", sum(!is.na(cams$place_geoid)),
        "; in an active county subdivision: ", sum(!is.na(cams$cousub_geoid)),
        "; in no county polygon: ", sum(is.na(cams$county_geoid)))

# 3. Geography -> agency keys ------------------------------------------------------------------------
cs_key <- function(g) paste0(substr(g, 1, 2), substr(g, 6, 10))   # cousub GEOID -> state + 5-digit code
valid_codes <- c(inc_places$GEOID, cs_key(act_cousub$GEOID))
muni_all <- ag |> filter(agency_type == "Municipal police")
muni <- muni_all |> filter(!is.na(place_fips), place_fips %in% valid_codes) |> mutate(place_source = "leaic")
message("Municipal PDs: ", nrow(muni_all), "; LEAIC place code found in TIGER ", TIGER_YEAR, ": ", nrow(muni),
        "; missing or not found: ", nrow(muni_all) - nrow(muni))

# 3a. Fallback for PDs with no usable LEAIC code (new since 2012, or place recoded): exact name match
#     to a TIGER incorporated place in the same state, unique on both sides, place not already taken.
src <- readLines("R/04_method_a.R")
eval(parse(text = src[grep("^basic <- function", src):(grep("^# Agency side", src) - 1)]))
pl_names <- st_drop_geometry(inc_places) |> transmute(GEOID, STATEFP,
  pkey = basic(str_remove(NAME, "\\s*\\(balance\\)")))
pl_names <- pl_names |> add_count(STATEFP, pkey, name = "n_pl") |> filter(n_pl == 1)
nm <- muni_all |> filter(!ori %in% muni$ori) |>
  mutate(akey = parse_name(name)$core2, STATEFP = STATES$fips[match(state, STATES$abbr)]) |>
  add_count(STATEFP, akey, name = "n_ag") |> filter(n_ag == 1) |>
  inner_join(pl_names, by = c("STATEFP", "akey" = "pkey")) |>
  filter(!GEOID %in% muni$place_fips)
message("  + matched by exact name to a ", TIGER_YEAR, " place (flagged): ", nrow(nm))
write_csv(nm |> select(ori, name, state, matched_place_geoid = GEOID), file.path(OUT, "method_b_pd_place_name_matches.csv"))
muni <- bind_rows(muni, nm |> mutate(place_fips = GEOID, place_source = "name_match_tiger") |> select(names(muni)))

dup_place <- muni |> count(place_fips) |> filter(n > 1)
message("Place codes with >1 municipal PD (largest FBI population kept): ", nrow(dup_place), " (", sum(dup_place$n), " agencies)")
write_csv(muni |> semi_join(dup_place, by = "place_fips") |> select(place_fips, ori, name, population_fbi) |> arrange(place_fips),
          file.path(OUT, "method_b_places_with_multiple_pds.csv"))
place_to_pd <- muni |> arrange(place_fips, desc(coalesce(population_fbi, -1))) |> distinct(place_fips, .keep_all = TRUE) |>
  select(geo = place_fips, pd_ori = ori)

cty <- ag |> filter(agency_type != "Municipal police", !is.na(county_fips))
multi_cty <- cty |> count(county_fips) |> filter(n > 1)
message("Counties with >1 sheriff/county police agency (largest FBI population kept): ", nrow(multi_cty))
write_csv(cty |> semi_join(multi_cty, by = "county_fips") |> select(county_fips, ori, name, agency_type, population_fbi) |>
            arrange(county_fips, desc(population_fbi)), file.path(OUT, "method_b_counties_with_multiple_county_agencies.csv"))
county_to_ag <- cty |> arrange(county_fips, desc(coalesce(population_fbi, -1))) |> distinct(county_fips, .keep_all = TRUE) |>
  select(geo = county_fips, cty_ori = ori)

# 3b. County-wide municipal PDs: FBI population served >= 50% of the county's ACS population
#     (Las Vegas Metro, Honolulu, Charlotte-Mecklenburg, Metro Nashville, Louisville Metro, Athens-Clarke).
#     Used for cameras in a consolidated-government "balance" place (TIGER C8) with no PD, and for
#     counties with no sheriff/county-police record.
cty_pop <- st_drop_geometry(counties) |> select(county_fips = GEOID, county_pop = pop_acs)
cw <- muni_all |> filter(!is.na(county_fips)) |> left_join(cty_pop, by = "county_fips") |>
  filter(population_fbi >= 0.5 * county_pop) |>
  arrange(county_fips, desc(population_fbi)) |> distinct(county_fips, .keep_all = TRUE)
message("County-wide municipal PDs (>= 50% of county population): ", nrow(cw))
write_csv(cw |> select(county_fips, ori, name, population_fbi, county_pop), file.path(OUT, "method_b_countywide_pds.csv"))
countywide <- cw |> select(geo = county_fips, cw_ori = ori)
c8 <- inc_places$GEOID[inc_places$CLASSFP == "C8"]

# 4. Assign -------------------------------------------------------------------------------------------
b <- cams |> select(osm_id, b_excluded, place_geoid, cousub_geoid, county_geoid)
b <- b |> left_join(place_to_pd, by = c("place_geoid" = "geo")); n_log(b, "after place -> PD join")
# county subdivision GEOID is 10 digits (state+county+cousub); LEAIC place code is state + 5 digits
b <- b |> mutate(cousub_key = if_else(is.na(cousub_geoid), NA, paste0(substr(cousub_geoid, 1, 2), substr(cousub_geoid, 6, 10)))) |>
  left_join(place_to_pd |> rename(cs_pd_ori = pd_ori), by = c("cousub_key" = "geo")); n_log(b, "after county subdivision -> PD join")
b <- b |> left_join(county_to_ag, by = c("county_geoid" = "geo")); n_log(b, "after county -> sheriff join")
b <- b |> left_join(countywide, by = c("county_geoid" = "geo")); n_log(b, "after county-wide PD join")
stopifnot(nrow(b) == nrow(cams))

b <- b |> mutate(
  b_level = case_when(
    b_excluded ~ "excluded_private",
    !is.na(pd_ori) ~ "place",
    !is.na(cs_pd_ori) ~ "county_subdivision",
    place_geoid %in% c8 & !is.na(cw_ori) ~ "consolidated_countywide_pd",
    is.na(cty_ori) & !is.na(cw_ori) ~ "countywide_pd_no_county_agency",
    !is.na(place_geoid) & !is.na(cty_ori) ~ "place_without_pd_to_county",
    !is.na(cty_ori) ~ "county",
    TRUE ~ "unassigned"),
  b_ori = case_when(b_level == "place" ~ pd_ori, b_level == "county_subdivision" ~ cs_pd_ori,
                    b_level %in% c("county", "place_without_pd_to_county") ~ cty_ori,
                    b_level %in% c("consolidated_countywide_pd", "countywide_pd_no_county_agency") ~ cw_ori, TRUE ~ NA))
message("\nMethod B assignment level:"); print(count(b, b_level))
b <- b |> left_join(cams |> select(osm_id, excl_surveillance_private, excl_operator_type, excl_operator_text), by = "osm_id")
saveRDS(b |> select(osm_id, b_excluded, excl_surveillance_private, excl_operator_type, excl_operator_text,
                    place_geoid, cousub_geoid, county_geoid, b_level, b_ori), file.path(PROC, "method_b.rds"))
