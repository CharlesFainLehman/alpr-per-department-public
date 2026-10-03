# Combine the camera-level results; write cameras.csv, agencies.csv, summary tables, density plot.
#
# Three per-agency measures, kept separate (none is an ownership inventory or a bound):
#   tagged     (method A) the camera's operator tag names the agency. Can include wrong matches.
#   located    (method B) cameras inside the agency's area, excluding cameras whose operator is a
#              private party or another public body. Includes cameras of unknown operator.
#   attributed tagged cameras, plus untagged / vendor-only / unmatched-police-tag cameras located in
#              the agency's area (inferred). attr_basis says which.
# None measures what an agency can SEARCH: shared networks (e.g., Flock sharing / national lookup)
# extend access far beyond cameras in its area.
source("R/00_setup.R")
library(ggplot2)

cams <- readRDS(file.path(PROC, "osm_alpr.rds"))
a    <- readRDS(file.path(PROC, "method_a.rds"))
b    <- readRDS(file.path(PROC, "method_b.rds"))
cls  <- readRDS(file.path(PROC, "operator_class.rds"))
ag   <- readRDS(file.path(PROC, "agencies.rds"))
geo  <- readRDS(file.path(PROC, "agency_geo_status.rds"))

# Snapshot guard: every intermediate must describe exactly this camera set.
for (nm_ in c("a", "b", "cls")) {
  ids <- get(nm_)$osm_id
  if (!setequal(ids, cams$osm_id) || anyDuplicated(ids))
    stop("Intermediate '", nm_, "' does not match the current OSM snapshot; rerun 04, 04b, 05.")
}

n_log(cams, "cameras")
x <- cams |> left_join(a, by = "osm_id"); n_log(x, "cameras + method A")
x <- x |> left_join(cls, by = "osm_id");  n_log(x, "cameras + operator class")
x <- x |> left_join(b, by = "osm_id");    n_log(x, "cameras + method B")
stopifnot(nrow(x) == nrow(cams))
nm <- ag |> select(ori, name, agency_type, county_fips)
x <- x |> left_join(nm |> rename(a_ori = ori, a_name = name, a_type = agency_type, a_county = county_fips), by = "a_ori") |>
  left_join(nm |> select(-county_fips) |> rename(b_ori = ori, b_name = name, b_type = agency_type), by = "b_ori")
n_log(x, "cameras + agency names")
x <- x |> add_count(lat, lon, name = "n_same_coords") |> mutate(
  is_flock = coalesce(str_detect(str_to_lower(paste(manufacturer, brand)), "flock"), FALSE),
  a_in_agency_county = if_else(is.na(a_ori), NA, coalesce(a_county == county_geoid, FALSE)),
  attr_ori = case_when(op_class %in% c("local_police", "local_government") ~ a_ori,
                       op_class %in% c("missing", "vendor", "unclassified", "police_unmatched") ~ b_ori,
                       TRUE ~ NA),
  attr_basis = case_when(is.na(attr_ori) ~ NA,
                         op_class %in% c("local_police", "local_government") ~ "tagged",
                         TRUE ~ paste0("inferred_location_", op_class)),
  a_b_compare = case_when(
    is.na(a_ori) & is.na(b_ori) ~ "neither",
    is.na(a_ori) ~ "B only",
    is.na(b_ori) ~ "A only",
    a_ori == b_ori ~ "agree",
    TRUE ~ "disagree")) |> select(-a_county)
saveRDS(x, file.path(PROC, "cameras_assigned.rds"))
message("A vs B comparison:"); print(count(x, a_b_compare))
message("Attribution basis:"); print(count(x, attr_basis, sort = TRUE))
message("Cameras sharing exact coordinates with another camera: ", sum(x$n_same_coords > 1))

write_csv(x |> select(osm_id, lat, lon, state, manufacturer, brand, operator, operator_type, surveillance,
                      surveillance_zone, last_edit, osm_version, is_flock, n_same_coords, op_class, op_class_source,
                      a_ori, a_name, a_type, a_basis, a_in_agency_county,
                      b_status, b_ori, b_name, b_type, place_geoid, cousub_geoid, county_geoid, n_polygon_overlaps,
                      attr_ori, attr_basis, a_b_compare),
          file.path(OUT, "cameras.csv"))
write_csv(x |> select(osm_id, all_tags), gzfile(file.path(OUT, "cameras_osm_tags.csv.gz")))

# Agency table ----------------------------------------------------------------------------------------
cnt <- function(col, flock_only = FALSE, filt = NULL) {
  d <- if (flock_only) filter(x, is_flock) else x
  if (!is.null(filt)) d <- d[filt(d), ]
  d |> filter(!is.na(.data[[col]])) |> count(ori = .data[[col]])
}
INFERRED_B <- c("inferred_no_pd_in_place", "inferred_countywide_pd", "direct_place_name_mismatch", "direct_cousub_name_mismatch")
agt <- ag |> left_join(geo, by = "ori") |>
  select(ori, name, agency_type, state, record_status, geo_status, place_fips, county_fips, county_source,
         population_fbi, pop_year) |>
  left_join(cnt("a_ori") |> rename(cameras_tagged = n), by = "ori") |>
  left_join(cnt("b_ori") |> rename(cameras_located = n), by = "ori") |>
  left_join(cnt("b_ori", filt = \(d) d$b_status %in% INFERRED_B) |> rename(located_via_inferred_rule = n), by = "ori") |>
  left_join(cnt("attr_ori") |> rename(cameras_attributed = n), by = "ori") |>
  left_join(cnt("attr_ori", filt = \(d) coalesce(d$attr_basis != "tagged", FALSE)) |> rename(attributed_inferred = n), by = "ori") |>
  left_join(cnt("a_ori", TRUE) |> rename(flock_tagged = n), by = "ori") |>
  left_join(cnt("b_ori", TRUE) |> rename(flock_located = n), by = "ori") |>
  left_join(cnt("attr_ori", TRUE) |> rename(flock_attributed = n), by = "ori") |>
  mutate(across(c(starts_with("cameras_"), starts_with("flock_"), located_via_inferred_rule, attributed_inferred), \(v) coalesce(v, 0L)),
         located_zero_type = case_when(
           cameras_located > 0 ~ NA,
           record_status == "historical" ~ "historical record (not assigned)",
           geo_status %in% c("place_code_resolved", "county_code_resolved") ~ "no mapped cameras in area",
           TRUE ~ paste0("no usable geography: ", geo_status)),
         per10k_located = if_else(population_fbi > 0, 1e4 * cameras_located / population_fbi, NA),
         per10k_attributed = if_else(population_fbi > 0, 1e4 * cameras_attributed / population_fbi, NA))
n_log(agt, "agency table (all local PDs + sheriffs, incl. zero cameras)")
stopifnot(sum(agt$cameras_tagged) == sum(!is.na(x$a_ori)), sum(agt$cameras_located) == sum(!is.na(x$b_ori)),
          sum(agt$cameras_attributed) == sum(!is.na(x$attr_ori)))
write_csv(agt, file.path(OUT, "agencies.csv"))
message("Agencies with zero located cameras, by reason:"); print(count(agt, located_zero_type, sort = TRUE))

# Summary statistics (current agencies only; historical ORIs excluded) -------------------------------
popbin <- function(p) cut(p, c(-Inf, 2500, 10000, 25000, 50000, 100000, 250000, Inf), right = FALSE,
                          labels = c("<2.5k", "2.5k-10k", "10k-25k", "25k-50k", "50k-100k", "100k-250k", "250k+"))
cur <- agt |> filter(record_status != "historical") |>
  mutate(pop_bin = coalesce(as.character(popbin(population_fbi)), "unknown"))
stats <- function(d, col) d |> summarise(
  agencies = n(), cameras = sum(.data[[col]]), mean = mean(.data[[col]]), median = median(.data[[col]]),
  p10 = quantile(.data[[col]], .10), p25 = quantile(.data[[col]], .25), p75 = quantile(.data[[col]], .75),
  p90 = quantile(.data[[col]], .90), p99 = quantile(.data[[col]], .99), max = max(.data[[col]]), .groups = "drop")
MEASURES <- c(located = "cameras_located", attributed = "cameras_attributed", tagged = "cameras_tagged")
summ <- list()
for (m in names(MEASURES)) {
  col <- MEASURES[[m]]
  sets <- list(
    "agencies with >=1 camera" = filter(cur, .data[[col]] >= 1),
    "agencies with usable geography" = filter(cur, geo_status %in% c("place_code_resolved", "county_code_resolved", "countywide_only")),
    "all current agencies" = cur)
  for (set in names(sets)) {
    d <- sets[[set]]
    summ[[length(summ) + 1]] <- bind_rows(
      stats(d, col) |> mutate(group_var = "overall", group = "all"),
      stats(group_by(d, group = agency_type), col) |> mutate(group_var = "agency_type"),
      stats(group_by(d, group = pop_bin), col) |> mutate(group_var = "population_bin")) |>
      mutate(measure = m, set = set, .before = 1)
  }
}
summ <- bind_rows(summ) |> relocate(group_var, group, .after = set)
write_csv(summ, file.path(OUT, "summary_stats.csv"))
print(summ |> filter(group_var == "overall"), width = Inf)

# Density plot -----------------------------------------------------------------------------------------
LAB <- c(located = "Located in agency's area", attributed = "Attributed (tagged + inferred)", tagged = "Tagged to agency")
dd <- bind_rows(lapply(names(MEASURES), \(m) cur |> transmute(measure = LAB[[m]], n = .data[[MEASURES[[m]]]]))) |>
  filter(n >= 1) |> mutate(measure = factor(measure, levels = unname(LAB)))
p <- ggplot(dd, aes(n, colour = measure)) +
  geom_density(linewidth = 0.8, adjust = 1.2) +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000)) +
  scale_colour_manual(values = setNames(c("#eb6834", "#1baf7a", "#2a78d6"), unname(LAB)), name = NULL) +
  labs(x = "Mapped ALPR cameras per agency (log scale)", y = "Density",
       title = "Mapped license plate reader cameras per local police agency",
       subtitle = sprintf("Current agencies with at least one camera under each measure. OpenStreetMap (OSM) data pulled %s.\nCounts of mapped cameras, not verified inventories; whole-number counts make the curves bumpy at 1-3.",
                          readLines(file.path(PROC, "osm_pull_date.txt")))) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top", legend.justification = "left", panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"))
ggsave(file.path(OUT, "density_cameras_per_agency.png"), p, width = 9, height = 5, dpi = 150)
