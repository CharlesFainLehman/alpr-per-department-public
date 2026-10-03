# Density of mapped cameras located in each agency's area, with labeled lines at the mean, median
# and 99th percentile. Current agencies with at least one located camera.
source("R/00_setup.R")
library(ggplot2)

ags <- read_csv(file.path(OUT, "agencies.csv"), show_col_types = FALSE) |> filter(record_status != "historical")
pos <- ags |> filter(cameras_located >= 1)
st <- tibble(stat = c("Median", "Mean", "99th percentile"),
             value = c(median(pos$cameras_located), mean(pos$cameras_located), quantile(pos$cameras_located, 0.99)))
st <- st |> mutate(label = paste0(stat, ": ", ifelse(value == round(value), sprintf("%.0f", value), sprintf("%.1f", value))))
print(st)

p <- ggplot(pos, aes(cameras_located)) +
  geom_density(colour = "#eb6834", fill = "#eb6834", alpha = 0.15, linewidth = 0.8, adjust = 1.2) +
  geom_vline(data = st, aes(xintercept = value), colour = "#0b0b0b", linewidth = 0.5, linetype = "dashed") +
  geom_text(data = st, aes(x = value * 1.06, y = 0.75, label = label), hjust = 0, size = 3.3, colour = "#0b0b0b") +
  coord_cartesian(ylim = c(0, 0.78)) +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000),
                labels = c("1", "2", "5", "10", "20", "50", "100", "200", "500", "1,000", "2,000")) +
  labs(x = "License plate reader cameras located in agency's area, mapped in OpenStreetMap (log scale)", y = "Density",
       title = "Mapped license plate reader cameras per local police agency",
       subtitle = sprintf("Local police and sheriffs with at least one camera mapped in OpenStreetMap (OSM), the crowdsourced map\nused by DeFlock. Cameras located in the agency's area, excluding other operators (n = %s agencies). Data pulled %s.",
                          format(nrow(pos), big.mark = ","), readLines(file.path(PROC, "osm_pull_date.txt"))),
       caption = "Counts of mapped cameras, not verified inventories. Whole-number counts make the curve bumpy at 1-3.") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"),
        plot.caption = element_text(colour = "#52514e", hjust = 0, size = 8.5))
ggsave(file.path(OUT, "density_cameras_per_agency_stats.png"), p, width = 10, height = 5.5, dpi = 150)
