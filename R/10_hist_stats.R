# Distribution of mapped cameras located in each agency's area, with labeled lines at the mean, median
# and 99th percentile. Current agencies with at least one located camera.
source("R/00_setup.R")
source("R/theme_cf.R")

ags <- read_csv(file.path(OUT, "agencies.csv"), show_col_types = FALSE) |> filter(record_status != "historical")
pos <- ags |> filter(cameras_located >= 1)
st <- tibble(stat = c("Median", "Mean", "99th percentile"),
             value = c(median(pos$cameras_located), mean(pos$cameras_located), quantile(pos$cameras_located, 0.99)))
st <- st |> mutate(label = paste0(stat, ": ", ifelse(value == round(value), sprintf("%.0f", value), sprintf("%.1f", value))))
print(st)

# Bar chart of labeled ranges, equal-width bars, height = share of agencies. (A smoothed density on a
# log axis dips into the gaps between whole numbers; log-width bins can't be equal at 1, 2, 3.)
# Mean / median / 99th-percentile lines are placed inside their range by log interpolation.
edges <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, Inf)
bins <- tibble(lo = head(edges, -1), hi = tail(edges, -1)) |>
  mutate(i = row_number(),
         n = map2_int(lo, hi, \(a, b) sum(pos$cameras_located >= a & pos$cameras_located < b)),
         share = n / nrow(pos),
         lab = case_when(hi == Inf ~ paste0(lo, "+"), hi - lo == 1 ~ as.character(lo), TRUE ~ paste0(lo, "-", hi - 1)))
stopifnot(sum(bins$n) == nrow(pos))
print(bins |> select(lab, n, share), n = Inf)
pos_x <- function(v) { k <- max(which(bins$lo <= v)); b <- bins[k, ]
  hi <- if (is.finite(b$hi)) b$hi else max(pos$cameras_located) + 1
  k - 0.5 + (log(v) - log(b$lo)) / (log(hi) - log(b$lo)) }
st <- st |> mutate(x = map_dbl(value, pos_x))
ymax <- ceiling(max(bins$share) * 1.3 * 20) / 20

lab_y <- ymax * c(0.97, 0.88, 0.97)
p <- ggplot(bins) +
  geom_col(aes(x = i, y = share), fill = cf_orange, width = 0.8) +
  geom_text(aes(x = i, y = share, label = if_else(share < 0.005, "<1%", percent(share, accuracy = 1))), vjust = -0.5, family = "Liberation Sans",
            size = 19 / .pt, colour = cf_axis) +
  geom_segment(data = st, aes(x = x, xend = x, y = 0, yend = lab_y - ymax * 0.03), colour = cf_ink, linewidth = 1, linetype = "dashed") +
  geom_text(data = st, aes(x = x, y = lab_y, label = label), family = "Liberation Sans", size = 19 / .pt, colour = cf_ink) +
  scale_x_continuous(breaks = bins$i, labels = bins$lab, expand = expansion(add = 0.4)) +
  scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, ymax), expand = expansion(mult = c(0, 0))) +
  labs(x = NULL, y = NULL,
       title = "Most agencies have fewer than 10 mapped plate readers",
       subtitle = sprintf("Share of %s local police and sheriff's offices with at least one camera, by cameras mapped in OpenStreetMap\nin the agency's area (cameras tagged to other operators excluded). Mapped cameras, not verified inventories.",
                          format(nrow(pos), big.mark = ",")),
       caption = cf_caption(sprintf("OpenStreetMap (DeFlock layer) via Overpass, pulled %s; FBI Crime Data Explorer; BJS LEAIC; Census TIGER/Line.",
                                    readLines(file.path(PROC, "osm_pull_date.txt"))))) +
  theme_cf(title_size = 34)
cf_save(p, file.path(OUT, "hist_cameras_per_agency_stats.png"))
