# Build the agency list: local police departments and sheriff's offices.
#
# Sources
#   FBI Crime Data Explorer (CDE) agency directory                 -> ORI, name, type, county
#   FBI CDE "Law Enforcement Employees" file (lee_1960_2025.csv)  -> population served
#   BJS LEAIC 2012 (ICPSR 35158, committed in data/raw/leaic/)    -> place / county FIPS
# The two FBI files are pinned in data/snapshots/ (fbi_cde_agencies_<date>, fbi_lee_<date>). If those
# are missing they are downloaded again; the CDE directory is served from a "LATEST" address and changes.
source("R/00_setup.R")

# 1. FBI files ------------------------------------------------------------------------------------------
cde_snap <- latest_snapshot("fbi_cde_agencies"); lee_snap <- latest_snapshot("fbi_lee")
if (is.na(cde_snap) || is.na(lee_snap)) {
  today <- format(Sys.Date())
  cdir <- file.path(RAW, "fbi", "cde_agency_by_state")
  for (s in STATES$abbr)
    fetch(sprintf("https://cde.ucr.cjis.gov/LATEST/agency/byStateAbbr/%s", s), file.path(cdir, paste0(s, ".json")))
  cde <- map_dfr(STATES$abbr, \(s) {
    js <- fromJSON(file.path(cdir, paste0(s, ".json")), simplifyVector = FALSE)
    map_dfr(unlist(js, recursive = FALSE), \(a) tibble(
      ori = a$ori, cde_name = a$agency_name, cde_type = a$agency_type_name,
      state = a$state_abbr, cde_counties = a$counties %||% NA_character_))
  })
  cde_snap <- file.path("data/snapshots", sprintf("fbi_cde_agencies_%s.csv.gz", today))
  write_csv(cde, gzfile(cde_snap))
  # The employee file comes from a signed S3 URL; only records since 2020 are kept in the snapshot.
  signed <- fromJSON(sprintf("https://cde.ucr.cjis.gov/LATEST/s3/signedurl?key=%s",
                             paste0("additional-datasets/law-enforcement/", LEE_FILE)))[[1]]
  lee_raw <- read_csv(fetch(signed, file.path(RAW, "fbi", LEE_FILE)), col_types = cols(.default = "c"))
  lee_snap <- file.path("data/snapshots", sprintf("fbi_lee_%s.csv.gz", today))
  lee_raw |> filter(as.integer(data_year) >= 2020) |>
    select(ori, data_year, pub_agency_name, pub_agency_unit, agency_type_name, state_abbr, population) |>
    write_csv(gzfile(lee_snap))
}
message("FBI snapshots: ", basename(cde_snap), ", ", basename(lee_snap))

cde <- read_csv(cde_snap, col_types = cols(.default = "c"))
n_log(cde, "CDE agency directory, all types, 50 states + DC")
cde <- distinct(cde, ori, .keep_all = TRUE)
n_log(cde, "CDE after de-duplicating ORI")
print(count(cde, cde_type, sort = TRUE))

# 2. Population served: most recent year (2020 or later) each ORI appears in the employee file --------------
lee <- read_csv(lee_snap, col_types = cols(.default = "c"))
n_log(lee, "LEE file, records since 2020")
lee <- lee |> mutate(data_year = as.integer(data_year), population = as.numeric(na_if(population, "NULL")),
                     state_abbr = if_else(state_abbr == "NB", "NE", state_abbr))   # the LEE file codes Nebraska as NB
lee_latest <- lee |> arrange(ori, desc(data_year)) |> distinct(ori, .keep_all = TRUE) |>
  transmute(ori, lee_name = pub_agency_name, lee_unit = na_if(pub_agency_unit, "NULL"), lee_type = agency_type_name,
            lee_state = state_abbr, pop_year = data_year, population_fbi = population)
n_log(lee_latest, "LEE, latest record per ORI since 2020")
message("  LEE latest-year distribution:"); print(count(lee_latest, pop_year))

# 3. Combine and keep local police + sheriffs ------------------------------------------------------
ag <- full_join(cde, lee_latest, by = "ori")
n_log(ag, "CDE full-join LEE on ORI")
message("  in CDE only: ", sum(is.na(ag$lee_name)), "; in LEE only: ", sum(is.na(ag$cde_name)))
ag <- ag |> mutate(
  state = coalesce(state, lee_state),
  type_fbi = coalesce(cde_type, lee_type),
  # LEE names are the place name; LEE unit carries "Police Department" etc. where present.
  name = coalesce(cde_name, str_squish(paste(lee_name, coalesce(lee_unit, ""))))
)
ag <- ag |> filter(state %in% STATES$abbr)
n_log(ag, "agencies in 50 states + DC")
ag <- ag |> filter(type_fbi %in% c("City", "County"))
n_log(ag, "agencies with FBI type City or County")

# Name is checked before FBI type: the FBI types some city sheriffs (Baltimore City, Richmond City...) as "City".
ag <- ag |> mutate(agency_type = case_when(
  str_detect(name, regex("sheriff", ignore_case = TRUE)) ~ "Sheriff",
  type_fbi == "City" ~ "Municipal police",
  str_detect(name, regex("police|public safety", ignore_case = TRUE)) ~ "County police",
  TRUE ~ "County (type unclear)"))   # LEE-only rows named just "<County>"
print(count(ag, agency_type))

# Record status. Only "current_cde" and "employee_file_only_recent" agencies receive cameras and enter the
# summary distributions; the others stay in the table, flagged.
#   contract_city  a city that pays the county sheriff for policing but is listed in the CDE directory as its own
#                  "Police Department" (Moreno Valley, Weston, Pontiac). Identified as a municipal agency with no
#                  employee-file record since 2020 that is in California, where every real department reports
#                  staff, or whose ORI ends in "X", the FBI's mark for these units elsewhere. Its cameras go to
#                  the county agency. Contract cities that report staff under the city's own ORI (Broward County,
#                  FL; King County, WA) are not caught.
#   historical     an ORI missing from the current CDE directory whose latest employee-file record is before 2024
#                  (FL0160200 "Jacksonville", last reported 2020; the current agency is the Jacksonville Sheriff's Office).
ag <- ag |> mutate(record_status = case_when(
  agency_type == "Municipal police" & is.na(pop_year) & (state == "CA" | str_ends(ori, "X")) ~ "contract_city",
  !is.na(cde_name) ~ "current_cde",
  !is.na(pop_year) & pop_year >= 2024 ~ "employee_file_only_recent",
  TRUE ~ "historical"))
print(count(ag, record_status))

# 4. LEAIC FIPS codes ------------------------------------------------------------------------------
# ICPSR requires a login, so this file was downloaded by hand: https://www.icpsr.umich.edu/web/NACJD/studies/35158
# (DS1, tab-delimited 35158-0001-Data.tsv or R 35158-0001-Data.rda).
leaic_files <- list.files(file.path(RAW, "leaic"), pattern = "35158-0001-Data\\.(tsv|rda)$",
                          recursive = TRUE, full.names = TRUE)
if (!length(leaic_files)) {
  stop("LEAIC not found. Download ICPSR 35158 DS1 (Delimited or R format) and place ",
       "35158-0001-Data.tsv or .rda under data/raw/leaic/. See README.md.")
}
f <- leaic_files[1]
if (grepl("\\.rda$", f)) { e <- new.env(); load(f, envir = e); leaic <- get(ls(e)[1], envir = e) } else
  leaic <- read_tsv(f, col_types = cols(.default = "c"), locale = locale(encoding = "latin1"))
leaic <- as_tibble(leaic) |> mutate(across(everything(), as.character))
names(leaic) <- toupper(names(leaic))
n_log(leaic, "LEAIC 2012 rows")
need <- c("ORI9", "FIPS_ST", "FIPS_COUNTY", "FPLACE")
if (!all(need %in% names(leaic)))
  stop("LEAIC columns not as expected. Found: ", paste(names(leaic), collapse = ", "))

leaic <- leaic |> filter(!is.na(ORI9), ORI9 != "-1", nchar(ORI9) == 9) |>
  transmute(ori = ORI9, leaic_name = NAME,
            county_fips = paste0(str_pad(FIPS_ST, 2, pad = "0"), str_pad(FIPS_COUNTY, 3, pad = "0")),
            # 99xxx = county-level (sheriffs), 99991 = multi-jurisdiction, 99999 = none
            place_fips = ifelse(is.na(FPLACE) | FPLACE %in% c("-1", "") | str_starts(str_pad(FPLACE, 5, pad = "0"), "99"), NA,
                                paste0(str_pad(FIPS_ST, 2, pad = "0"), str_pad(FPLACE, 5, pad = "0")))) |>
  mutate(county_fips = ifelse(grepl("^-|999$", county_fips), NA, county_fips))
# ORIs whose LEAIC record is a different agency (the ORI was later reused). Their LEAIC place code is dropped;
# 06_locate_cameras.R then matches the PD to a place by name.
LEAIC_REUSED <- c(CA0421200 = "Buellton PD; LEAIC: Santa Barbara Airport Patrol, Goleta's code",
                  KY0565000 = "Lyndon PD; LEAIC: Graymoor/Devondale PD",
                  NY0102500 = "Stockport Town PD; LEAIC: Columbia Greene Humane Society, Hudson's code")
leaic <- leaic |> mutate(place_fips = if_else(ori %in% names(LEAIC_REUSED), NA, place_fips))
dups <- leaic |> count(ori) |> filter(n > 1)
message("  LEAIC ORIs appearing more than once (first kept): ", nrow(dups))
leaic <- distinct(leaic, ori, .keep_all = TRUE)
n_log(leaic, "LEAIC unique ORI9")

ag <- left_join(ag, leaic, by = "ori")
n_log(ag, "agencies after LEAIC join")
message("  agencies with no LEAIC record (ORI new since 2012 or changed): ", sum(is.na(ag$leaic_name)))
message("  Municipal PDs with no place FIPS: ", sum(ag$agency_type == "Municipal police" & is.na(ag$place_fips)))
message("  County agencies with no county FIPS: ", sum(ag$agency_type != "Municipal police" & is.na(ag$county_fips)))

# County codes that no longer exist in TIGER (Connecticut counties, split or renamed counties) are dropped
# so the CDE-name fallback below applies; otherwise a camera could never fall in that county.
counties <- st_drop_geometry(readRDS(file.path(PROC, "counties.rds")))
defunct <- !is.na(ag$county_fips) & !ag$county_fips %in% counties$GEOID
message("  LEAIC county codes not in TIGER ", TIGER_YEAR, " (dropped): ", sum(defunct))
ag$county_fips[defunct] <- NA

# County FIPS fallback: agencies with no LEAIC county get the county named in the FBI CDE directory
# (e.g., St. Charles County PD, MO0922400, an ORI not in LEAIC). Exact name match within state.
cnorm <- function(x) stringi::stri_trans_general(x, "Latin-ASCII") |> str_to_upper() |> str_replace_all("[^A-Z ]", "") |> str_replace_all("\\bSAINT\\b", "ST") |> str_squish()
cty_keys <- bind_rows(
  counties |> transmute(STATEFP, GEOID, key = cnorm(NAME)),
  counties |> transmute(STATEFP, GEOID, key = cnorm(NAMELSAD))) |> distinct() |>
  add_count(STATEFP, key) |> filter(n == 1) |> select(-n)
ag <- ag |> mutate(STATEFP = STATES$fips[match(state, STATES$abbr)],
                   cde_first_county = cnorm(str_split_i(cde_counties, ",", 1))) |>
  left_join(cty_keys, by = c("STATEFP", "cde_first_county" = "key")) |>
  mutate(county_source = case_when(!is.na(county_fips) ~ "leaic", !is.na(GEOID) ~ "cde_county_name", TRUE ~ NA),
         county_fips = coalesce(county_fips, GEOID)) |>
  select(-GEOID, -cde_first_county)
message("  county FIPS filled from CDE county name: ", sum(ag$county_source == "cde_county_name", na.rm = TRUE),
        "; still missing: ", sum(is.na(ag$county_fips)))

ag <- ag |> select(ori, name, state, agency_type, record_status, population_fbi, pop_year,
                   leaic_name, place_fips, county_fips, county_source)
saveRDS(ag, file.path(PROC, "agencies.rds"))
