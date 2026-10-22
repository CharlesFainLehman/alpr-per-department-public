# The five charts, from saved tables only (no pipeline objects), so they can be redrawn on their own:
#   output/png/validation_web_scatter.png          reported vs. mapped cameras per agency
#   output/png/hist_cameras_per_agency_stats.png   all agencies: distribution of mapped cameras per agency
#   output/png/hist_reported_cameras_per_agency.png the validation agencies: distribution of their published counts
#   output/png/hist_findingflock_public_operators.png Finding Flock's public operators: tagged cameras per operator
#   output/png/court_observations_per_day.png      captures per day in ALPR court rulings vs. Carpenter
# Inputs: output/csv/validation_web_comparison.csv and validation_web_metrics.csv (from 08_validate.R),
# output/csv/agencies.csv (from 07_count_per_agency.R),
# the OSM snapshot's date (from its file name) and docs/alpr_observation_counts.xlsx (compiled by hand).
source("R/00_setup.R")
source("R/theme_cf.R")

pull_date <- snapshot_date(latest_snapshot("osm_alpr_raw"))
core <- read_csv(file.path(OUT_CSV, "validation_web_comparison.csv"), col_types = cols(as_of_date = "c")) |>
  filter(core) |> mutate(year = suppressWarnings(as.integer(substr(as_of_date, 1, 4))))
met <- read_csv(file.path(OUT_CSV, "validation_web_metrics.csv"), show_col_types = FALSE) |>
  filter(subset == "core: current, fixed, agency-operated")
stopifnot(nrow(met) == 1, met$n == nrow(core))
web_caption <- paste0(
  sprintf("Mapped: cameras tagged to the agency, plus untagged cameras in its area; Flock only where the reported figure is a Flock count (%d of %d).\n",
          sum(core$flock_only), nrow(core)),
  cf_caption(sprintf("Agency websites, government documents and news reports (%s-%s); OpenStreetMap via Overpass, pulled %s.",
                     min(core$year, na.rm = TRUE), max(core$year, na.rm = TRUE), pull_date)))

# 1. Scatter: reported vs. mapped ---------------------------------------------------------------------------
BRK <- c(0, 1, 3, 10, 30, 100, 300, 1000, 3000)
LIM <- c(0, 3000)
stopifnot(max(core$reported, core$osm_located) <= LIM[2])
p <- ggplot(core, aes(reported, osm_located)) +
  geom_abline(slope = 1, intercept = 0, colour = cf_axis, linewidth = 0.6, linetype = "dashed") +
  geom_point(colour = cf_orange, alpha = 0.7, size = 2.6, stroke = 0) +
  annotate("text", x = 1800, y = 700, label = "Equal counts", hjust = 0.5, vjust = 0.5, family = "Liberation Sans",
           size = 21 / .pt, colour = cf_axis) +
  scale_x_continuous(trans = "log1p", breaks = BRK, labels = label_comma(), limits = LIM, expand = expansion(mult = 0.02)) +
  scale_y_continuous(trans = "log1p", breaks = BRK, labels = label_comma(), limits = LIM, expand = expansion(mult = 0.02)) +
  labs(x = NULL, y = NULL,
       title = "Mapped camera counts track what agencies report",
       subtitle = sprintf("Fixed license plate reader cameras per agency, %d agencies (log scale). Across: count reported by the\nagency. Up: cameras mapped in OpenStreetMap in its area. %.0f%% of agencies are within a factor of two.",
                          nrow(core), 100 * met$within_2x),
       caption = web_caption) +
  theme_cf(title_size = 36)
cf_save(p, file.path(OUT_PNG, "validation_web_scatter.png"))

# 2-3. Bar charts: share of agencies by number of cameras ---------------------------------------------------------
# Equal-width bars for labeled ranges (a smoothed density on a log axis dips between whole numbers); median, mean and
# 99th-percentile lines placed inside their range by log interpolation. Agencies with at least one camera.
bar_chart <- function(n, fill, title, subtitle, caption, file, empty_label = "") {
  edges <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, Inf)
  bins <- tibble(lo = head(edges, -1), hi = tail(edges, -1)) |>
    mutate(i = row_number(), k = map2_int(lo, hi, \(a, b) sum(n >= a & n < b)), share = k / length(n),
           lab = case_when(hi == Inf ~ paste0(lo, "+"), hi - lo == 1 ~ as.character(lo), TRUE ~ paste0(lo, "-", hi - 1)))
  stopifnot(sum(bins$k) == length(n))
  pos_x <- function(v) { k <- max(which(bins$lo <= v)); b <- bins[k, ]
    hi <- if (is.finite(b$hi)) b$hi else max(n) + 1
    k - 0.5 + (log(v) - log(b$lo)) / (log(hi) - log(b$lo)) }
  ymax <- ceiling(max(bins$share) * 1.3 * 20) / 20
  st <- tibble(value = c(median(n), mean(n), quantile(n, 0.99, names = FALSE)),
               label = sprintf(c("Median: %.0f", "Mean: %.1f", "99th percentile: %.0f"), value)) |>
    mutate(x = map_dbl(value, pos_x), y = ymax * c(0.97, 0.88, 0.97),
           # a line that falls on a bar starts above the bar's percentage label
           bar = round(x), y0 = if_else(abs(x - bar) < 0.4, bins$share[bar] + ymax * 0.07, 0))
  print(st); print(bins |> select(lab, k, share))
  p <- ggplot(bins) +
    geom_col(aes(x = i, y = share), fill = fill, width = 0.8) +
    geom_text(aes(x = i, y = share, label = case_when(k == 0 ~ empty_label, share < 0.005 ~ "<1%", TRUE ~ percent(share, accuracy = 1))), vjust = -0.5,
              family = "Liberation Sans", size = 19 / .pt, colour = cf_axis) +
    geom_segment(data = st, aes(x = x, xend = x, y = y0, yend = y - ymax * 0.03), colour = cf_ink, linewidth = 1, linetype = "dashed") +
    geom_text(data = st, aes(x = x, y = y, label = label), family = "Liberation Sans", size = 19 / .pt, colour = cf_ink) +
    scale_x_continuous(breaks = bins$i, labels = bins$lab, expand = expansion(add = 0.4)) +
    scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, ymax), expand = expansion(mult = c(0, 0))) +
    labs(x = NULL, y = NULL, title = title, subtitle = subtitle, caption = caption) +
    theme_cf(title_size = 34)
  cf_save(p, file.path(OUT_PNG, file))
}

# 2. OSM: all current agencies with at least one mapped camera
osm_n <- read_csv(file.path(OUT_CSV, "agencies.csv"), show_col_types = FALSE) |>
  filter(is_current(record_status), cameras_located >= 1) |> pull(cameras_located)
stopifnot(mean(osm_n < 10) > 0.5)   # the title's claim
bar_chart(osm_n, cf_orange,
  title = "Most agencies have fewer than 10 mapped plate readers",
  subtitle = sprintf("Share of %s local police and sheriff's offices with at least one camera, by cameras mapped in OpenStreetMap:\nthose tagged to the agency, plus untagged cameras in its area. Mapped cameras, not verified inventories.",
                     format(length(osm_n), big.mark = ",")),
  caption = cf_caption(sprintf("OpenStreetMap (DeFlock layer) via Overpass, pulled %s; FBI Crime Data Explorer; BJS LEAIC; Census TIGER/Line.", pull_date)),
  file = "hist_cameras_per_agency_stats.png")

# 3. Validation: counts the core agencies published themselves
rep_n <- core$reported[core$reported >= 1]
bar_chart(rep_n, cf_blue,
  title = sprintf("Agencies that publish counts report a median of %.0f cameras", median(rep_n)),
  subtitle = sprintf("Share of %d agencies by the number of fixed license plate reader cameras they reported (%d more reported none).\nCurrent programs; cameras the agency operates. Not a random sample: all have a published count.",
                     length(rep_n), sum(core$reported == 0)),
  caption = cf_caption(sprintf("Agency websites, government documents and news reports (%s-%s).", min(core$year, na.rm = TRUE), max(core$year, na.rm = TRUE))),
  file = "hist_reported_cameras_per_agency.png")

# 3b. Finding Flock: public operators' tagged cameras (R/findingflock_pull.R snapshot) ------------------------------
ff_file <- tail(sort(Sys.glob("data/snapshots/findingflock_operators_*.csv")), 1)
ff <- read_csv(ff_file, show_col_types = FALSE) |> filter(section == "Public agencies")
stopifnot(nrow(ff) > 0, min(ff$cameras) >= 5)
bar_chart(ff$cameras, cf_axis,
  title = sprintf("Finding Flock's list of public operators: a median of %.0f cameras", median(ff$cameras)),
  subtitle = sprintf("Share of %d public agencies listed by Finding Flock, an anti-surveillance site, by number of cameras whose\nOpenStreetMap operator tag names them. Only operators with at least five tagged cameras are listed, and most\ncameras carry no operator tag, so each count is a floor.",
                     nrow(ff)),
  caption = cf_caption(sprintf("Finding Flock (findingflock.com/operators, %s), from OpenStreetMap contributors (ODbL).",
                               str_match(basename(ff_file), "_(\\d{4}-\\d{2}-\\d{2})")[, 2])),
  file = "hist_findingflock_public_operators.png", empty_label = "not listed")

# 4. Court rulings: captures per day of one vehicle vs. Carpenter -------------------------------------------------
# Only records spanning a week or more (the sheet leaves shorter ones without a period) and only figures from the
# court record (press rows, tier "c", are left out). Rates divide each opinion's count by its period.
x <- readxl::read_excel("docs/alpr_observation_counts.xlsx", sheet = "Observation counts")
n_log(x, "cases in spreadsheet")
d <- x |>
  transmute(case = Case, tier = `Source tier`, n = `Captures (count)`, days = `Period (days)`) |>
  filter(!is.na(n), !is.na(days), !startsWith(tier, "c")) |>
  mutate(per_day = n / days)
n_log(d, "court-record rows with a count and a period of a week or more")
short <- c(
  "Carpenter v. United States (BENCHMARK)"     = "Carpenter (Supreme Court, cell-site data)",
  "Schmidt v. City of Norfolk (Schmidt car)"   = "Schmidt v. Norfolk: Schmidt's car",
  "Schmidt v. City of Norfolk (Arrington car)" = "Schmidt v. Norfolk: Arrington's car",
  "United States v. Kyle"                      = "U.S. v. Kyle (N.D. Okla.)",
  "United States v. Bowers"                    = "U.S. v. Bowers (W.D. Pa.)",
  "Commonwealth v. McCarthy"                   = "Commonwealth v. McCarthy (Mass.)*",
  "United States v. Sturdivant"                = "U.S. v. Sturdivant (N.D. Ohio)",
  "United States v. Brown (N.D. Ill.)"         = "U.S. v. Brown (N.D. Ill.)",
  "United States v. Martin"                    = "U.S. v. Martin (E.D. Va.)",
  "State v. Sidor"                             = "State v. Sidor (Ariz.)",
  "United States v. Jiles"                     = "U.S. v. Jiles (D. Neb.)")
stopifnot(all(d$case %in% names(short)))
d <- d |>
  mutate(label = short[case],
         val = case_when(grepl("BENCHMARK", case) ~ "101 a day",   # the Court's figure (12,898 / 127 = 101.6)
                         per_day >= 0.1 ~ sprintf("%.1f", per_day),
                         TRUE ~ sprintf("%.2f", per_day)),
         label = factor(label, levels = label[order(per_day)]))
print(d |> select(label, per_day), n = Inf)
p <- ggplot(d, aes(x = per_day, y = label)) +
  geom_vline(xintercept = d$per_day[grepl("BENCHMARK", d$case)], colour = cf_ink, linewidth = 0.8, linetype = "dashed") +
  geom_point(colour = cf_orange, size = 6) +
  geom_text(aes(label = val), hjust = 0, nudge_x = 0.12, family = "Liberation Sans", size = 18 / .pt, colour = cf_axis) +
  scale_x_log10(breaks = c(0.01, 0.1, 1, 10, 100), labels = c("0.01", "0.1", "1", "10", "100"),
                limits = c(0.02, 400), expand = expansion(mult = c(0.02, 0))) +
  labs(x = "Captures per day (log scale: each gridline is 10 times the one before)", y = NULL,
       title = "Plate-reader records in court are far thinner than Carpenter's",
       subtitle = "Times one vehicle was captured per day, in plate-reader rulings that give a count over a week or more.\nDashed line: Carpenter v. United States, 101 cell-site location points a day.",
       caption = cf_caption(paste0(
         "Court opinions (cites in docs/alpr_observation_counts.xlsx). Rates divide each opinion's count by its period. ",
         "*McCarthy counts days with a bridge crossing.\nKyle: \"more than 50\" records in a month. Schmidt: the court's counts; ",
         "press reported 526 and 849 (about 4 and 6 a day). Jiles: \"five or six\" hits in a six-month database."))) +
  theme_cf(title_size = 34) +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(color = cf_grid, linewidth = 0.6),
        axis.text.y = element_text(color = cf_ink, size = 19, hjust = 0),
        axis.title.x = element_text(color = cf_axis, size = 18, margin = margin(t = 10)))
cf_save(p, file.path(OUT_PNG, "court_observations_per_day.png"))
