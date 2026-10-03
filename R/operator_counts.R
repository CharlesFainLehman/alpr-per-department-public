# Rough count of OSM ALPR cameras per operator tag. No agency matching.
# Runs on whatever states 02_pull_osm.R has cached so far.
source("R/00_setup.R")

pull_dir <- sort(list.dirs(file.path(RAW, "osm"), recursive = FALSE), decreasing = TRUE)[1]
fs <- list.files(pull_dir, pattern = "^overpass_..\\.rds$", full.names = TRUE)
message("States cached: ", length(fs), " (", paste(sub("overpass_(..).rds", "\\1", basename(fs)), collapse = " "), ")")

tag <- function(t, k) if (is.null(t[[k]])) NA_character_ else as.character(t[[k]])
els <- unlist(lapply(fs, \(f) unlist(lapply(readRDS(f), \(p) p$json$elements), recursive = FALSE)), recursive = FALSE)
cams <- map_dfr(els, \(e) tibble(osm_id = as.character(e$id), lat = e$lat, lon = e$lon,
                                 operator = tag(e$tags, "operator"), manufacturer = tag(e$tags, "manufacturer")))
n_log(cams, "nodes across cached state bboxes")
cams <- distinct(cams, osm_id, .keep_all = TRUE)
n_log(cams, "unique nodes")

states <- readRDS(file.path(PROC, "states.rds"))
pts <- st_as_sf(cams, coords = c("lon", "lat"), crs = 4326) |> st_transform(st_crs(states))
cams$state <- vapply(st_intersects(pts, states), \(j) if (length(j)) states$STUSPS[j[1]] else NA_character_, "")
cams <- filter(cams, !is.na(state))
n_log(cams, "unique nodes inside a US state")

# Group operator names -----------------------------------------------------------------------------
# 1. Deterministic normalization (case, punctuation, possessives, "PD", "Dept", "Sheriff's Office",
#    "Saint"/"St", trailing state name or abbreviation, "X City of" -> "City of X").
# 2. Hand-made aliases (R/operator_aliases.csv) for abbreviations and typos. No fuzzy matching:
#    it pairs different agencies (Santa Clara / Santa Maria PD).
# 3. Agency/government-like names are grouped WITHIN a state (Farmington PD exists in NM, CT, MI...);
#    other names (chains, vendors, federal) are grouped nationally.
st_names <- setNames(str_to_lower(STATES$name), STATES$abbr)
norm_op <- function(x, st) {
  s <- str_to_lower(x) |> str_replace_all("[\u2019`]", "'") |> str_replace_all("'s\\b", "s") |>
    str_replace_all("&", " and ") |> str_replace_all("[^a-z0-9 ]", " ") |> str_squish() |>
    str_replace("^the ", "") |>
    str_replace_all(c("\\bsaint\\b" = "st", "\\bbch\\b" = "beach", "\\btwp\\b" = "township",
                      "\\bco\\b" = "county", "\\bsherr?iff?s?\\b" = "sheriff", "\\bdept\\b" = "department",
                      "\\bpd$" = "police", "\\bso$" = "sheriff"))
  # trailing state abbreviation / name matching the camera's state
  # (not after "of": "University of Florida" keeps its state name)
  s <- str_squish(str_remove(s, paste0("(?<! of)\\s(", str_to_lower(st), "|", st_names[st], ")$")))
  s <- str_replace(s, "^(.*) (city|town|village) of$", "\\2 of \\1")
  s <- str_replace_all(s, "\\bpolice (department|dep|division|services)\\b", "police")
  s <- str_replace_all(s, "\\bsheriff (office|department|dep)\\b", "sheriff")
  s
}
AGENCY_RX <- "police|sheriff|public safety|marshal|constable|\\bcity\\b|\\btown\\b|village|township|county|parish|borough"

aliases <- read_csv("R/operator_aliases.csv", col_types = cols(.default = "c")) |> mutate(state = coalesce(state, ""))
cams <- cams |> mutate(op = str_squish(operator)) |> filter(!is.na(op), op != "") |> bind_rows(
  cams |> mutate(op = str_squish(operator)) |> filter(is.na(op) | op == "") |> mutate(op = NA))
cams <- cams |> mutate(k = if_else(is.na(op), NA, norm_op(op, state)))
# apply aliases: state-specific first, then national
cams <- cams |> left_join(aliases |> filter(state != "") |> select(state, from_key, a1 = to_key), by = c("state", "k" = "from_key")) |>
  left_join(aliases |> filter(state == "") |> select(from_key, a2 = to_key), by = c("k" = "from_key")) |>
  mutate(k = coalesce(a1, a2, k), scope = if_else(str_detect(k, AGENCY_RX), state, "US")) |> select(-a1, -a2)
n_log(cams, "cameras after name normalization (row count unchanged)")

by_op <- cams |> filter(!is.na(k)) |>
  group_by(scope, k) |>
  summarise(operator = names(sort(table(op), decreasing = TRUE))[1], cameras = n(),
            n_spellings = n_distinct(op), spellings = paste(sort(unique(op)), collapse = " | "),
            states = paste(sort(unique(state)), collapse = " "),
            flock_share = mean(str_detect(coalesce(manufacturer, ""), regex("flock", ignore_case = TRUE))),
            .groups = "drop") |>
  mutate(operator = if_else(scope == "US", operator, paste0(operator, " (", scope, ")"))) |>
  arrange(desc(cameras)) |> select(operator, cameras, scope, states, n_spellings, spellings, flock_share)
write_csv(by_op |> filter(n_spellings > 1), file.path(OUT, "operator_merges_for_review.csv"))
message("Groups that merged >1 spelling: ", sum(by_op$n_spellings > 1),
        " (", sum(by_op$cameras[by_op$n_spellings > 1]), " cameras) -> output/operator_merges_for_review.csv")

tot <- nrow(cams); tagged <- sum(!is.na(cams$k))
message(sprintf("Cameras: %d; with operator tag: %d (%.1f%%); distinct operators: %d",
                tot, tagged, 100 * tagged / tot, nrow(by_op)))
write_csv(by_op, file.path(OUT, "cameras_per_operator.csv"))
print(by_op |> select(operator, cameras, n_spellings, flock_share) |> mutate(flock_share = round(flock_share, 2)), n = 40, width = 140)

# Distribution of cameras per operator name ---------------------------------------------------------
library(ggplot2)
LE_RX <- regex("police|sheriff|\\bpd\\b|\\bso\\b|public safety|marshal|constable", ignore_case = TRUE)
by_op <- by_op |> mutate(group = if_else(str_detect(operator, LE_RX), "Police/sheriff-like name", "Other name"))
dist <- function(d) d |> summarise(operators = n(), mean = mean(cameras),
  p10 = quantile(cameras, .10), p25 = quantile(cameras, .25), median = median(cameras),
  p75 = quantile(cameras, .75), p90 = quantile(cameras, .90), p99 = quantile(cameras, .99), max = max(cameras),
  share_1_camera = mean(cameras == 1), total_cameras = sum(cameras), .groups = "drop")
ds <- bind_rows(dist(by_op) |> mutate(group = "All operator names", .before = 1), dist(group_by(by_op, group)))
write_csv(ds, file.path(OUT, "cameras_per_operator_distribution.csv"))
print(ds |> mutate(across(where(is.double), \(x) round(x, 2))), width = 160)

p <- ggplot(by_op, aes(cameras, fill = group)) +
  geom_histogram(breaks = 10^seq(0, 3.4, by = 0.2), colour = "#fcfcfb", linewidth = 0.5) +
  scale_x_log10(breaks = c(1, 3, 10, 30, 100, 300, 1000)) +
  scale_fill_manual(values = c("Police/sheriff-like name" = "#2a78d6", "Other name" = "#eb6834"), name = NULL) +
  facet_wrap(~group, ncol = 1, scales = "free_y") +
  labs(x = "Cameras per operator name (log scale)", y = "Operator names",
       title = "OSM ALPR cameras per operator tag",
       subtitle = sprintf("%d states cached; %d tagged cameras of %d; spelling variants merged", length(fs), tagged, tot)) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none", panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"))
ggsave(file.path(OUT, "cameras_per_operator_hist.png"), p, width = 8, height = 6, dpi = 150)
