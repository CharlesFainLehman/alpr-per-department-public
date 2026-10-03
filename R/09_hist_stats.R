# Distribution of mapped cameras located in each agency's area, with labeled lines at the mean, median
# and 99th percentile. Current agencies with at least one located camera.
source("R/00_setup.R")
library(ggplot2)

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
ymax <- max(bins$share) * 1.2

p <- ggplot(bins) +
  geom_col(aes(x = i, y = share), fill = "#eb6834", width = 0.92) +
  geom_text(aes(x = i, y = share, label = scales::percent(share, accuracy = 0.1)), vjust = -0.4, size = 3.1, colour = "#52514e") +
  geom_vline(data = st, aes(xintercept = x), colour = "#0b0b0b", linewidth = 0.5, linetype = "dashed") +
  geom_label(data = st, aes(x = x, y = ymax * c(0.98, 0.98, 0.98), label = label), size = 3.2, colour = "#0b0b0b",
             fill = "#fcfcfb", border.colour = NA, label.padding = unit(0.12, "lines")) +
  scale_x_continuous(breaks = bins$i, labels = bins$lab, expand = expansion(add = 0.4)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1), limits = c(0, ymax), expand = expansion(mult = c(0, 0.02))) +
  labs(x = "License plate reader cameras located in agency's area, mapped in OpenStreetMap",
       y = "Share of agencies",
       title = "Mapped license plate reader cameras per local police agency",
       subtitle = sprintf("Local police and sheriffs with at least one camera mapped in OpenStreetMap (OSM), the crowdsourced map\nused by DeFlock. Cameras located in the agency's area, excluding other operators (n = %s agencies). Data pulled %s.",
                          format(nrow(pos), big.mark = ","), readLines(file.path(PROC, "osm_pull_date.txt"))),
       caption = "Counts of mapped cameras, not verified inventories. Dashed lines are placed within their range on a log scale.") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"),
        plot.caption = element_text(colour = "#52514e", hjust = 0, size = 8.5))
ggsave(file.path(OUT, "hist_cameras_per_agency_stats.png"), p, width = 10, height = 5.5, dpi = 150)
