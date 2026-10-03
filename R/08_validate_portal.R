# Validate against agency-reported Flock camera counts (N&O "Private Eyes", Flock transparency
# portals scraped 2024-04-26; the file name says 2023 but the `updated` field is 2024-04-26).
source("R/00_setup.R")
library(ggplot2)
library(stringdist)

repo <- file.path(RAW, "private_eyes", "repo")
if (!dir.exists(repo))
  system2("git", c("clone", "--depth", "1", "https://github.com/mcclatchy-southeast/private_eyes", repo))
writeLines(system2("git", c("-C", repo, "log", "-1", shQuote("--format=%H %cd")), stdout = TRUE),
           file.path(RAW, "private_eyes", "commit.txt"))

pe <- read_csv(file.path(repo, "data", "latest_usage04262023.csv"), col_types = cols(.default = "c"))
n_log(pe, "N&O latest usage file")
pe <- pe |> filter(!str_detect(agency, "Flock|Training|DNU"))
n_log(pe, "after dropping Flock / Training / DNU rows")
pe <- pe |> mutate(reported = suppressWarnings(as.numeric(number_of_owned_cameras)))
message("  rows with missing camera count (dropped): ", sum(is.na(pe$reported)))
pe <- pe |> filter(!is.na(reported))
n_log(pe, "after dropping missing camera counts")

# Parse "<Name> <ST> <PD|SO>" style names ---------------------------------------------------------
STATE_OVERRIDE <- c("Yuba County Sheriffs Office" = "CA")   # only US Yuba County is in California
st_tok <- function(x) {
  toks <- str_split(str_replace_all(x, "[^A-Za-z ]", " "), "\\s+")[[1]]
  hits <- toks[toks %in% STATES$abbr & !toks %in% c("PD", "SO")]
  if (length(hits)) tail(hits, 1) else NA_character_
}
pe <- pe |> mutate(
  state = coalesce(unname(STATE_OVERRIDE[agency]), vapply(agency, st_tok, "")),
  name_wo_state = str_squish(str_replace(agency, paste0("\\b", state, "\\b"), " ")),
  name_wo_state = str_replace(name_wo_state, "\\bTwp\\b", "Township"))
message("  rows with no parseable state: ", sum(is.na(pe$state)))

source("R/name_parser.R")
ag <- readRDS(file.path(PROC, "agencies_fbi.rds"))
ag_p <- bind_cols(ag |> select(ori, name, state, agency_type), parse_name(ag$name)) |>
  mutate(kind = if_else(agency_type == "Sheriff", "sheriff", "police"),
         core2 = if_else(agency_type != "Municipal police", core, core2))
pe <- bind_cols(pe, parse_name(pe$name_wo_state) |> select(kind, core, core2)) |>
  mutate(core2 = if_else(str_detect(core, "\\b(county|parish)\\b"), core, core2))

match_one <- function(state, kind, core, core2) {
  cand <- ag_p[ag_p$state %in% state & (kind == "none" | ag_p$kind == kind), ]
  if (!nrow(cand)) return(tibble(ori = NA, basis = "no_candidates", dist = NA, cand_name = NA))
  e1 <- cand[cand$core == core, ]
  if (nrow(e1) == 1) return(tibble(ori = e1$ori, basis = "exact", dist = 0, cand_name = e1$name))
  e2 <- cand[cand$core2 == core2, ]
  if (nrow(e2) == 1) return(tibble(ori = e2$ori, basis = "exact_no_muni_word", dist = 0, cand_name = e2$name))
  if (nrow(e1) > 1 || nrow(e2) > 1) return(tibble(ori = NA, basis = "ambiguous", dist = 0, cand_name = paste(e2$name, collapse = " | ")))
  d <- stringdist(core2, cand$core2, method = "jw", p = 0.1); o <- order(d)
  ok <- d[o[1]] <= 0.05 && (length(o) == 1 || d[o[2]] - d[o[1]] >= 0.05)
  tibble(ori = if (ok) cand$ori[o[1]] else NA, basis = if (ok) "fuzzy" else "unmatched",
         dist = d[o[1]], cand_name = cand$name[o[1]])
}
mm <- pmap_dfr(pe |> select(state, kind, core, core2), match_one)
pe <- bind_cols(pe, mm)
n_log(pe, "validation agencies after matching")
print(count(pe, basis))
write_csv(pe |> select(id, agency, state, kind, reported, basis, dist, matched_ori = ori, cand_name),
          file.path(REVIEW, "validation_agency_matches.csv"))

# Camera counts by measure (Flock only) --------------------------------------------------------------
# This is a HISTORICAL comparison: portal counts are from 2024-04-26, OSM from the pull date. It shows
# whether the measures rank agencies sensibly; it does not establish current per-agency accuracy.
cams <- readRDS(file.path(PROC, "cameras_assigned.rds"))
ags  <- readRDS(file.path(PROC, "agencies.rds"))
flock <- cams |> filter(is_flock)
cnt <- function(col, nm) flock |> filter(!is.na(.data[[col]])) |> count(ori = .data[[col]], name = nm)
v <- pe |> filter(!is.na(ori)) |> select(id, agency, state, ori, reported, basis)
n_log(v, "matched validation agencies")
dup <- v |> count(ori) |> filter(n > 1)
if (nrow(dup)) message("  ORIs matched by >1 validation row (all kept): ", nrow(dup))
v <- v |> left_join(cnt("a_ori", "osm_tagged"), by = "ori") |> left_join(cnt("b_ori", "osm_located"), by = "ori") |>
  left_join(cnt("attr_ori", "osm_attributed"), by = "ori") |>
  mutate(across(starts_with("osm_"), \(z) coalesce(z, 0L))) |>
  left_join(ags |> select(ori, agency_type, population_fbi, record_status), by = "ori")
n_log(v, "after joining OSM counts")
write_csv(v, file.path(OUT, "validation_comparison.csv"))

metrics <- function(osm, rep) {
  pos <- rep > 0; r <- osm[pos] / rep[pos]
  tibble(n = length(rep), n_reported_positive = sum(pos),
         pearson_r = cor(osm, rep), spearman_rho = cor(osm, rep, method = "spearman"),
         pearson_r_log1p = cor(log1p(osm), log1p(rep)),
         median_ratio_osm_over_reported = median(r),
         share_within_factor_2 = mean(r >= 0.5 & r <= 2), share_below_half = mean(r < 0.5), share_above_double = mean(r > 2),
         median_abs_error = median(abs(osm - rep)),
         share_osm_zero = mean(osm == 0), share_osm_above_reported = mean(osm > rep))
}
MEAS <- c(tagged = "osm_tagged", located = "osm_located", attributed = "osm_attributed")
res <- bind_rows(lapply(names(MEAS), \(m) metrics(v[[MEAS[[m]]]], v$reported) |> mutate(measure = m, .before = 1)))
print(res, width = Inf)
write_csv(res, file.path(OUT, "validation_metrics.csv"))

# by agency type and population served
popbin <- function(p) cut(p, c(-Inf, 10000, 50000, 250000, Inf), right = FALSE, labels = c("<10k", "10k-50k", "50k-250k", "250k+"))
by_grp <- bind_rows(
  v |> group_by(group = agency_type) |> group_modify(\(d, k) metrics(d$osm_located, d$reported)) |> mutate(group_var = "agency_type"),
  v |> group_by(group = coalesce(as.character(popbin(population_fbi)), "unknown")) |>
    group_modify(\(d, k) metrics(d$osm_located, d$reported)) |> mutate(group_var = "population_served")) |>
  mutate(measure = "located", .before = 1) |> relocate(group_var, .after = measure)
print(by_grp |> select(measure, group_var, group, n, median_ratio_osm_over_reported, share_within_factor_2, pearson_r_log1p), width = Inf)
write_csv(by_grp, file.path(OUT, "validation_metrics_by_group.csv"))

# largest residuals for review
resid <- v |> filter(reported > 0) |> mutate(ratio_located = osm_located / reported) |>
  arrange(desc(abs(log((osm_located + 1) / (reported + 1))))) |>
  select(agency, ori, agency_type, reported, osm_tagged, osm_located, osm_attributed, ratio_located)
write_csv(resid, file.path(OUT, "validation_largest_residuals.csv"))
message("Largest residuals:"); print(head(resid, 15), width = Inf)

LABS <- c(tagged = "Tagged to agency", located = "Located in agency's area", attributed = "Attributed (tagged + inferred)")
long <- bind_rows(lapply(names(MEAS), \(m) v |> transmute(measure = LABS[[m]], reported, osm = .data[[MEAS[[m]]]]))) |>
  mutate(measure = factor(measure, levels = unname(LABS)))
lab <- res |> mutate(measure = factor(LABS[measure], levels = unname(LABS)),
                     txt = sprintf("n = %d   r(log) = %.2f\nmedian ratio = %.2f   within 2x: %.0f%%",
                                   n, pearson_r_log1p, median_ratio_osm_over_reported, 100 * share_within_factor_2))
brks <- c(0, 1, 3, 10, 30, 100, 300, 1000)
p <- ggplot(long, aes(reported, osm)) +
  geom_abline(slope = 1, intercept = 0, colour = "#52514e", linewidth = 0.4, linetype = "dashed") +
  geom_point(colour = "#2a78d6", alpha = 0.6, size = 2, stroke = 0) +
  geom_text(data = lab, aes(x = 0, y = Inf, label = txt), hjust = 0, vjust = 1.3, size = 2.9, colour = "#52514e",
            lineheight = 1, inherit.aes = FALSE) +
  scale_x_continuous(trans = "log1p", breaks = brks) + scale_y_continuous(trans = "log1p", breaks = brks) +
  facet_wrap(~measure) +
  labs(x = "Agency-reported Flock cameras, April 2024 (log scale, +1)",
       y = "Mapped OSM Flock cameras, Oct. 2026 (log scale, +1)",
       title = "Mapped OpenStreetMap counts vs. agency-reported Flock counts",
       subtitle = "Historical comparison (2.5 years apart): shows ranking, not current accuracy. Dashed line = equal counts.") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), text = element_text(colour = "#0b0b0b"),
        plot.subtitle = element_text(colour = "#52514e"))
ggsave(file.path(OUT, "validation_scatter.png"), p, width = 12, height = 5, dpi = 150)
