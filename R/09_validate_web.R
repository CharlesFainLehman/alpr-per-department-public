# Extended validation: publicly reported camera counts collected from the web
# (agency websites, government documents, news quoting officials), one row per agency, in
# data/validation_web/*.csv. Every row carries a URL and an exact quote.
#
# Compared with OSM counts for the same agency. Rows whose figure includes mobile readers or
# shared/private cameras are kept in the table but excluded from the headline metrics.
# The comparison is with the count as of the source date; OSM is as of the pull date.
source("R/00_setup.R")
source("R/theme_cf.R")
library(stringdist)

files <- list.files("data/validation_web", pattern = "^(northeast|midwest|south|west)(_[0-9]+)?\\.csv$", full.names = TRUE)
stopifnot(length(files) > 0)
w <- map_dfr(files, \(f) read_csv(f, col_types = cols(.default = "c")) |> mutate(file = basename(f)))
n_log(w, "web-reported rows")
# Program status from the collector's notes (keyword rules) plus reviewed overrides
DISC_RX <- regex("remov|turned off|turn off|shut (off|down)|deactivat|disabl|terminat|cancel|suspend|paus|lapse|inactive|\\bended\\b|discontinu|\\bending\\b|dropped|switch(ing)? off|expir|not renew|decommission|phas(ed|ing) out", ignore_case = TRUE)
PLAN_RX <- regex("planned|approved|not confirmed|installing|to be installed|will install|proposed|pilot|contracted|grant-funded|not yet installed|replac", ignore_case = TRUE)
ovr <- read_csv("data/validation_web/status_overrides.csv", col_types = cols(.default = "c"))
w <- w |> mutate(reported = suppressWarnings(as.numeric(reported_cameras)),
                 state = str_to_upper(str_trim(state)),
                 mobile_flag = str_to_lower(coalesce(includes_mobile_or_shared, "")),
                 mobile_or_shared = mobile_flag != "no",          # yes / unknown / unclear
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
w <- w |> distinct(state, agency_name, .keep_all = TRUE)
n_log(w, "after removing duplicate state+agency rows")

# Match to the agency list (current agencies only), same parser as method A --------------------------
source("R/name_parser.R")
ag <- readRDS(file.path(PROC, "agencies.rds")) |> filter(record_status != "historical")
ag_p <- bind_cols(ag |> select(ori, name, state, agency_type), parse_name(ag$name)) |>
  mutate(kind = if_else(agency_type == "Sheriff", "sheriff", "police"),
         core2 = if_else(agency_type != "Municipal police", core, core2))
w <- w |> mutate(hint = case_when(agency_type == "sheriff" ~ "sheriff", agency_type %in% c("municipal", "county_police") ~ "police", TRUE ~ "none"))
# reviewed name aliases (source name -> FBI agency name)
ALIAS <- c("Indianapolis Metropolitan Police Department" = "Indianapolis Police Department",
           "North Attleborough Police Department" = "North Attleboro Police Department",
           "York-Poquoson Sheriff's Office" = "York County Sheriff's Office",
           "Kansas City Missouri Police Department" = "Kansas City Police Department",
           "Carson City Sheriff's Office" = "Carson City County Sheriff's Office",
           "Lakeside Park-Crestview Hills Police Authority" = "Lakeside Park-Crestview Hills Police Department",
           "Metro Nashville Police Department" = "Metropolitan Nashville Police Department",
           "Do\u00f1a Ana County Sheriff's Office" = "Dona Ana County Sheriff's Office")
pw <- parse_name(coalesce(unname(ALIAS[w$agency_name]), w$agency_name))
w <- bind_cols(w, pw |> select(kind, core, core2, core_typed)) |>
  mutate(kind = if_else(kind == "none", hint, kind),
         core2 = if_else(str_detect(core, "\\b(county|parish)\\b"), core, core2))

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
w <- bind_cols(w, pmap_dfr(w |> select(state, kind, core, core2, core_typed), match_one))
n_log(w, "rows after matching")
print(count(w, basis))
write_csv(w |> filter(is.na(ori)) |> select(state, agency_name, basis, cand_name, url), file.path(REVIEW, "validation_web_unmatched.csv"))

# OSM counts: all-vendor measures, plus Flock-only when the source says the cameras are Flock --------
cams <- readRDS(file.path(PROC, "cameras_assigned.rds"))
cnt <- function(d, col, nm) d |> filter(!is.na(.data[[col]])) |> count(ori = .data[[col]], name = nm)
osm <- ag |> select(ori, agency_type_fbi = agency_type, population_fbi) |>
  left_join(cnt(cams, "b_ori", "located_all"), by = "ori") |>
  left_join(cnt(cams, "attr_ori", "attributed_all"), by = "ori") |>
  left_join(cnt(cams, "a_ori", "tagged_all"), by = "ori") |>
  left_join(cnt(filter(cams, is_flock), "b_ori", "located_flock"), by = "ori") |>
  left_join(cnt(filter(cams, is_flock), "attr_ori", "attributed_flock"), by = "ori") |>
  mutate(across(c(located_all, attributed_all, tagged_all, located_flock, attributed_flock), \(z) coalesce(z, 0L)))
v <- w |> filter(!is.na(ori)) |> left_join(osm, by = "ori") |>
  mutate(flock_only = str_detect(str_to_lower(coalesce(vendor, "")), "flock") & !str_detect(str_to_lower(coalesce(vendor, "")), "and|,|;|/|\\+|other"),
         osm_located = if_else(flock_only, located_flock, located_all),
         osm_attributed = if_else(flock_only, attributed_flock, attributed_all))
dupe <- v |> count(ori) |> filter(n > 1)
if (nrow(dupe)) { message("  ORIs matched by >1 row (most recent kept): ", nrow(dupe))
  v <- v |> arrange(ori, desc(as_of_date)) |> distinct(ori, .keep_all = TRUE) }
n_log(v, "matched web-reported agencies")
write_csv(v |> select(state, agency_name, ori, matched_name = cand_name, basis, agency_type_fbi, reported, program_status, mobile_flag,
                      vendor, flock_only, as_of_date, source_type, osm_tagged = tagged_all, osm_located, osm_attributed,
                      url, quote, notes),
          file.path(OUT, "validation_web_comparison.csv"))

metrics <- function(osm, rep) {
  pos <- rep > 0; r <- osm[pos] / rep[pos]
  tibble(n = length(rep), pearson_r_log1p = cor(log1p(osm), log1p(rep)), spearman_rho = cor(osm, rep, method = "spearman"),
         median_ratio = median(r), within_2x = mean(r >= 0.5 & r <= 2),
         below_half = mean(r < 0.5), above_double = mean(r > 2), median_abs_error = median(abs(osm - rep)))
}
core <- v |> filter(!mobile_or_shared, program_status == "current")
n_log(core, "core comparison set (current program, fixed agency-operated count)")
res <- bind_rows(
  metrics(core$osm_located, core$reported) |> mutate(measure = "located", subset = "core: current, fixed, agency-operated", .before = 1),
  metrics(core$osm_attributed, core$reported) |> mutate(measure = "attributed", subset = "core: current, fixed, agency-operated", .before = 1),
  { d <- filter(core, reported > 0); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "core, excluding agencies reporting zero", .before = 1) },
  { d <- filter(core, year >= 2025); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "fixed, source dated 2025-2026", .before = 1) },
  { d <- filter(core, agency_type_fbi == "Municipal police"); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "municipal police", .before = 1) },
  { d <- filter(core, agency_type_fbi != "Municipal police"); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "sheriffs / county police", .before = 1) },
  { d <- filter(v, mobile_or_shared); if (nrow(d) > 2) metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "figures incl. mobile/shared or unclear", .before = 1) },
  { d <- filter(v, program_status == "discontinued"); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "discontinued programs (last count)", .before = 1) },
  { d <- filter(v, program_status == "planned_or_contracted"); metrics(d$osm_located, d$reported) |> mutate(measure = "located", subset = "planned / contracted counts", .before = 1) })
print(res, width = Inf)
write_csv(res, file.path(OUT, "validation_web_metrics.csv"))

BRK <- c(0, 1, 3, 10, 30, 100, 300, 1000, 3000)
LIM <- c(0, 3000)
p <- ggplot(core, aes(reported, osm_located)) +
  geom_abline(slope = 1, intercept = 0, colour = cf_axis, linewidth = 0.6, linetype = "dashed") +
  geom_point(colour = cf_orange, alpha = 0.7, size = 2.6, stroke = 0) +
  annotate("text", x = 1800, y = 700, label = "Equal counts", hjust = 0.5, vjust = 0.5, family = "Liberation Sans",
           size = 21 / .pt, colour = cf_axis) +
  scale_x_continuous(trans = "log1p", breaks = BRK, labels = label_comma(), limits = LIM, expand = expansion(mult = 0.02)) +
  scale_y_continuous(trans = "log1p", breaks = BRK, labels = label_comma(), limits = LIM, expand = expansion(mult = 0.02)) +
  labs(x = NULL, y = NULL,
       title = "Mapped camera counts mostly match what agencies report",
       subtitle = sprintf("Fixed license plate reader cameras per agency, %d agencies (log scale). Across: count reported by the\nagency. Up: cameras mapped in OpenStreetMap in its area. %.0f%% of agencies are within a factor of two.",
                          nrow(core), 100 * res$within_2x[1]),
       caption = cf_caption(sprintf("Agency websites, government documents and news reports (%s-%s); OpenStreetMap via Overpass, pulled %s.",
                                    min(core$year, na.rm = TRUE), max(core$year, na.rm = TRUE), readLines(file.path(PROC, "osm_pull_date.txt"))))) +
  theme_cf(title_size = 36)
cf_save(p, file.path(OUT, "validation_web_scatter.png"))

# Reported counts as an independent estimate of cameras per agency -------------------------------------
# The web sample is not random: it holds agencies that have cameras and whose count was published
# (often because of a council debate or news story). It says nothing about agencies with zero cameras,
# and skews toward larger and more contested programs. Compared here with OSM for the SAME agencies.
dstat <- function(x, nm) tibble(estimate = nm, agencies = length(x), mean = mean(x), median = median(x),
                                p25 = quantile(x, .25), p75 = quantile(x, .75), p90 = quantile(x, .90), max = max(x))
core <- core |> mutate(rep_per10k = if_else(population_fbi > 0, 1e4 * reported / population_fbi, NA),
                       osm_per10k = if_else(population_fbi > 0, 1e4 * osm_located / population_fbi, NA))
dens <- bind_rows(
  dstat(core$reported, "reported count (web sources)"),
  dstat(core$osm_located, "OSM located, same agencies"),
  dstat(na.omit(core$rep_per10k), "reported per 10,000 residents"),
  dstat(na.omit(core$osm_per10k), "OSM located per 10,000 residents, same agencies"))
popbin <- function(p) cut(p, c(-Inf, 10000, 50000, 250000, Inf), right = FALSE, labels = c("<10k", "10k-50k", "50k-250k", "250k+"))
dens_size <- core |> mutate(size = coalesce(as.character(popbin(population_fbi)), "unknown")) |>
  group_by(size) |> summarise(agencies = n(), median_reported = median(reported), median_osm_located = median(osm_located),
                              median_reported_per10k = median(rep_per10k, na.rm = TRUE), median_osm_per10k = median(osm_per10k, na.rm = TRUE),
                              median_ratio_osm_to_reported = median(osm_located[reported > 0] / reported[reported > 0]), .groups = "drop")
print(dens, width = Inf); print(dens_size, width = Inf)
write_csv(dens, file.path(OUT, "validation_web_density.csv"))
write_csv(dens_size, file.path(OUT, "validation_web_density_by_size.csv"))

# Minnesota BCA register of fixed LPR locations: a separate check ---------------------------------------
# The BCA publishes, per agency, the locations of stationary LPRs (Minn. Stat. 13.824). The register lists
# LOCATIONS, not cameras: one location can hold several readers (e.g. one per direction), and some entries
# give a device count in parentheses. Agencies that withheld their locations are left out. Agencies listing
# no fixed locations (mobile readers only) are kept in a separate "with zeros" comparison.
# Compared with all-vendor OSM located counts (the register is not vendor-specific).
mn <- read_csv("data/validation_web/mn_bca_fixed_lpr_locations.csv", col_types = cols(.default = "c")) |>
  mutate(state = "MN", listed = as.integer(listed_locations),
         withheld = str_detect(coalesce(locations, ""), regex("withheld", ignore_case = TRUE)),
         non_local = str_detect(agency_name, regex("State Patrol|Tribal|University|Airport", ignore_case = TRUE)),
         hint = if_else(str_detect(agency_name, regex("sheriff", ignore_case = TRUE)), "sheriff", "police"))
n_log(mn, "MN BCA register agencies")
pm <- parse_name(mn$agency_name)
mn <- bind_cols(mn, pm |> select(kind, core, core2, core_typed)) |>
  mutate(kind = if_else(kind == "none", hint, kind),
         core2 = if_else(str_detect(core, "\\b(county|parish)\\b"), core, core2))
mn <- bind_cols(mn, pmap_dfr(mn |> select(state, kind, core, core2, core_typed), match_one))
print(count(mn, non_local, withheld, basis))
mv <- mn |> filter(!non_local, !withheld, !is.na(ori)) |> left_join(osm |> select(ori, population_fbi, located_all), by = "ori")
n_log(mv, "MN BCA agencies matched, local, locations not withheld")
write_csv(mn |> left_join(osm |> select(ori, osm_located = located_all), by = "ori") |>
            select(agency_name, ori, matched_name = cand_name, basis, non_local, withheld, listed_locations = listed,
                   device_estimate, osm_located),
          file.path(OUT, "validation_mn_bca_comparison.csv"))
mmet <- function(d, nm) {
  pos <- d$listed > 0; r <- d$located_all[pos] / d$listed[pos]
  tibble(subset = nm, n = nrow(d), n_listing_zero = sum(!pos), pearson_r_log1p = cor(log1p(d$located_all), log1p(d$listed)),
         spearman_rho = cor(d$located_all, d$listed, method = "spearman"), median_ratio = median(r),
         within_2x = mean(r >= 0.5 & r <= 2), below_half = mean(r < 0.5), above_double = mean(r > 2),
         median_osm_where_zero_listed = if (any(!pos)) median(d$located_all[!pos]) else NA_real_)
}
mres <- bind_rows(mmet(filter(mv, listed > 0), "agencies listing >=1 fixed location"),
                  mmet(mv, "including agencies listing zero fixed locations"))
print(mres, width = Inf)
write_csv(mres, file.path(OUT, "validation_mn_bca_metrics.csv"))
