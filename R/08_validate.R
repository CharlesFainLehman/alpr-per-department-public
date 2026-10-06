# Check the located counts against camera counts that agencies have published.
#
# data/validation_web/<region>[_N].csv hold publicly reported counts collected from agency websites,
# government documents and news reports quoting officials: one row per agency, each with a URL and an exact
# quote. Each row is matched to the agency list and compared with the OSM cameras located in that agency's area.
#
# The core comparison keeps current programs whose figure is a count of fixed, agency-operated cameras
# (no mobile readers, no shared or private cameras). Where the source says the cameras are Flock, only
# Flock-tagged OSM cameras are counted.
#
# Writes output/csv/validation_web_comparison.csv (one row per matched agency; core = TRUE for the comparison
# set) and output/csv/validation_web_metrics.csv. A separate check against Minnesota's state register of
# fixed reader locations is added to the metrics.
source("R/00_setup.R")
source("R/name_parser.R")
library(stringdist)

# 1. Reported counts ---------------------------------------------------------------------------------------
files <- list.files("data/validation_web", pattern = "^(northeast|midwest|south|west)(_[0-9]+)?\\.csv$", full.names = TRUE)
stopifnot(length(files) > 0)
w <- map_dfr(files, \(f) read_csv(f, col_types = cols(.default = "c")) |> mutate(file = basename(f)))
n_log(w, "web-reported rows")

# Program status: keyword rules on the collector's notes, then reviewed overrides.
DISC_RX <- regex("remov|turned off|turn off|shut (off|down)|deactivat|disabl|terminat|cancel|suspend|paus|lapse|inactive|\\bended\\b|discontinu|\\bending\\b|dropped|switch(ing)? off|expir|not renew|decommission|phas(ed|ing) out", ignore_case = TRUE)
PLAN_RX <- regex("planned|approved|not confirmed|installing|to be installed|will install|proposed|pilot|contracted|grant-funded|not yet installed|replac", ignore_case = TRUE)
ovr <- read_csv("data/validation_web/status_overrides.csv", col_types = cols(.default = "c"))
stopifnot(!anyDuplicated(ovr[c("state", "agency_name")]))
w <- w |> mutate(reported = suppressWarnings(as.numeric(reported_cameras)),
                 state = str_to_upper(str_trim(state)),
                 mobile_flag = str_to_lower(coalesce(includes_mobile_or_shared, "")),   # yes / no / unknown / unclear
                 year = suppressWarnings(as.integer(substr(as_of_date, 1, 4))),
                 program_status = case_when(str_detect(coalesce(notes, ""), DISC_RX) ~ "discontinued",
                                            str_detect(coalesce(notes, ""), PLAN_RX) ~ "planned_or_contracted",
                                            TRUE ~ "current")) |>
  left_join(ovr |> select(state, agency_name, ovr_status = program_status), by = c("state", "agency_name")) |>
  mutate(program_status = coalesce(ovr_status, program_status)) |> select(-ovr_status)
print(count(w, program_status)); print(count(w, mobile_flag))
message("  rows with non-numeric count (dropped): ", sum(is.na(w$reported)),
        "; rows with no URL (dropped): ", sum(is.na(w$url) | w$url == ""))
w <- w |> filter(!is.na(reported), !is.na(url), url != "", state %in% STATES$abbr)
n_log(w, "rows with numeric count, URL and valid state")
stopifnot(!anyDuplicated(w[c("state", "agency_name")]))   # one row per agency across all files

# 2. Match to the agency list (current agencies), with the same name parser as 04 ---------------------------
ag <- readRDS(file.path(PROC, "agencies.rds")) |> filter(is_current(record_status))
ag_p <- bind_cols(ag |> select(ori, name, state, agency_type), parse_name(ag$name)) |>
  mutate(kind = if_else(agency_type == "Sheriff", "sheriff", "police"),
         core2 = if_else(agency_type != "Municipal police", core, core2))
# reviewed name aliases (source name -> FBI agency name)
ALIAS <- c("Indianapolis Metropolitan Police Department" = "Indianapolis Police Department",
           "North Attleborough Police Department" = "North Attleboro Police Department",
           "York-Poquoson Sheriff's Office" = "York County Sheriff's Office",
           "Kansas City Missouri Police Department" = "Kansas City Police Department",
           "Carson City Sheriff's Office" = "Carson City County Sheriff's Office",
           "Lakeside Park-Crestview Hills Police Authority" = "Lakeside Park-Crestview Hills Police Department",
           "Metro Nashville Police Department" = "Metropolitan Nashville Police Department",
           "Doña Ana County Sheriff's Office" = "Dona Ana County Sheriff's Office")

# names: agency names; hint: "sheriff" / "police" / "none" where the name has no agency word
parse_for_match <- function(names, hint) {
  bind_cols(parse_name(coalesce(unname(ALIAS[names]), names)) |> select(kind, core, core2, core_typed), hint = hint) |>
    mutate(kind = if_else(kind == "none", hint, kind),
           core2 = if_else(str_detect(core, "\\b(county|parish)\\b"), core, core2)) |> select(-hint)
}
# Exact match on the parsed name (typed, then plain, then without the municipal word, then with "county"
# added); else Jaro-Winkler within state and kind, accepted only if close and clearly better than the runner-up.
match_one <- function(state, kind, core, core2, core_typed) {
  cand <- ag_p[ag_p$state %in% state & (kind == "none" | ag_p$kind == kind), ]
  if (!nrow(cand)) return(tibble(ori = NA, basis = "no_candidates", cand_name = NA))
  if (!is.na(core_typed)) { e0 <- cand[cand$core == core_typed, ]
    if (nrow(e0) == 1) return(tibble(ori = e0$ori, basis = "exact_typed", cand_name = e0$name)) }
  e1 <- cand[cand$core == core, ]
  if (nrow(e1) == 1) return(tibble(ori = e1$ori, basis = "exact", cand_name = e1$name))
  e2 <- cand[cand$core2 == core2, ]
  if (nrow(e2) == 1) return(tibble(ori = e2$ori, basis = "exact_no_muni_word", cand_name = e2$name))
  e3 <- cand[cand$core2 == paste(core2, "county"), ]
  if (nrow(e3) == 1) return(tibble(ori = e3$ori, basis = "exact_county_added", cand_name = e3$name))
  if (nrow(e1) > 1 || nrow(e2) > 1) return(tibble(ori = NA, basis = "ambiguous", cand_name = paste(e2$name, collapse = " | ")))
  d <- stringdist(core2, cand$core2, method = "jw", p = 0.1); o <- order(d)
  ok <- d[o[1]] <= 0.05 && (length(o) == 1 || d[o[2]] - d[o[1]] >= 0.05)
  tibble(ori = if (ok) cand$ori[o[1]] else NA, basis = if (ok) "fuzzy" else "unmatched", cand_name = cand$name[o[1]])
}
match_names <- function(df) bind_cols(df, pmap_dfr(df |> select(state, kind, core, core2, core_typed), match_one))

hint <- case_when(w$agency_type == "sheriff" ~ "sheriff", w$agency_type %in% c("municipal", "county_police") ~ "police", TRUE ~ "none")
w <- match_names(bind_cols(w, parse_for_match(w$agency_name, hint)))
print(count(w, basis))
write_csv(w |> filter(is.na(ori)) |> select(state, agency_name, basis, cand_name, url), file.path(REVIEW, "validation_web_unmatched.csv"))

# 3. OSM located counts for the same agencies ---------------------------------------------------------------
cams <- readRDS(file.path(PROC, "cameras_assigned.rds")) |> filter(!is.na(located_ori))
osm <- ag |> select(ori, agency_type_fbi = agency_type, population_fbi) |>
  left_join(count(cams, ori = located_ori, name = "located_all"), by = "ori") |>
  left_join(count(filter(cams, is_flock), ori = located_ori, name = "located_flock"), by = "ori") |>
  mutate(across(c(located_all, located_flock), \(z) coalesce(z, 0L)))
v <- w |> filter(!is.na(ori)) |> select(-c(kind, core, core2, core_typed)) |> left_join(osm, by = "ori") |>
  mutate(vendor_l = str_to_lower(coalesce(vendor, "")),
         # Flock only: "Flock" / "Flock Safety", not "non-Flock" and not a list of vendors
         flock_only = str_detect(vendor_l, "flock") & !str_detect(vendor_l, "non-?\\s?flock|\\band\\b|,|;|/|\\+|\\bother"),
         osm_located = if_else(flock_only, located_flock, located_all),
         core = mobile_flag == "no" & program_status == "current") |> select(-vendor_l)
stopifnot(!anyDuplicated(v$ori))   # no agency matched by two source rows
n_log(v, "matched web-reported agencies")
write_csv(v |> select(state, agency_name, ori, matched_name = cand_name, basis, agency_type_fbi, population_fbi, reported,
                      program_status, mobile_flag, core, vendor, flock_only, as_of_date, source_type, osm_located,
                      url, quote, notes),
          file.path(OUT_CSV, "validation_web_comparison.csv"))

# 4. Metrics -----------------------------------------------------------------------------------------------
# osm vs reported, over all n agencies:
#   pearson_r_log1p   correlation of log(1 + count)
#   within_2x         share with osm between half and double the reported count; an agency reporting zero counts
#                     as within when osm is also zero (below_half / above_double split the rest)
#   median_ratio      median of osm / reported, over the n_ratio agencies reporting at least one camera
metrics <- function(osm, rep) {
  pos <- rep > 0; r <- if_else(pos, osm / rep, if_else(osm == 0, 1, Inf))
  tibble(n = length(rep), pearson_r_log1p = cor(log1p(osm), log1p(rep)), spearman_rho = cor(osm, rep, method = "spearman"),
         within_2x = mean(r >= 0.5 & r <= 2), below_half = mean(r < 0.5), above_double = mean(r > 2),
         n_ratio = sum(pos), median_ratio = median(r[pos]), median_abs_error = median(abs(osm - rep)))
}
core <- v |> filter(core)
n_log(core, "core comparison set (current program, fixed agency-operated count)")
popbin <- function(p) cut(p, c(-Inf, 10000, 50000, 250000, Inf), right = FALSE, labels = c("<10k", "10k-50k", "50k-250k", "250k+"))
res <- bind_rows(
  metrics(core$osm_located, core$reported) |> mutate(subset = "core: current, fixed, agency-operated", .before = 1),
  core |> mutate(size = coalesce(as.character(popbin(population_fbi)), "unknown")) |>
    reframe(metrics(osm_located, reported), .by = size) |>
    mutate(subset = paste("core, population", size), .before = 1) |> select(-size))

# 5. Minnesota BCA register of fixed LPR locations: a separate check ----------------------------------------
# The BCA publishes, per agency, the locations of stationary LPRs (Minn. Stat. 13.824). It lists LOCATIONS, not
# cameras (one location can hold several readers). Agencies that withheld their locations, non-local agencies
# and agencies listing no fixed location are left out. Compared with all-vendor located counts.
mn <- read_csv("data/validation_web/mn_bca_fixed_lpr_locations.csv", col_types = cols(.default = "c")) |>
  mutate(state = "MN", listed = as.integer(listed_locations),
         withheld = str_detect(coalesce(locations, ""), regex("withheld", ignore_case = TRUE)),
         non_local = str_detect(agency_name, regex("State Patrol|Tribal|University|Airport", ignore_case = TRUE)))
n_log(mn, "MN BCA register agencies")
mn_hint <- if_else(str_detect(mn$agency_name, regex("sheriff", ignore_case = TRUE)), "sheriff", "police")
mn <- match_names(bind_cols(mn, parse_for_match(mn$agency_name, mn_hint)))
print(count(mn, non_local, withheld, basis))
mv <- mn |> filter(!non_local, !withheld, !is.na(ori), listed > 0) |> left_join(osm |> select(ori, located_all), by = "ori")
n_log(mv, "MN BCA agencies matched, local, at least one location listed")
res <- bind_rows(res, metrics(mv$located_all, mv$listed) |> mutate(subset = "Minnesota BCA register: listed fixed locations", .before = 1))
print(res, width = Inf)
write_csv(res, file.path(OUT_CSV, "validation_web_metrics.csv"))
