# Distribution of cameras per agency for the 226 core web-validation agencies (current program, fixed,
# agency-operated count): publicly reported count vs. OSM cameras located in the same agencies' areas.
source("R/00_setup.R")
library(ggplot2)

v <- read_csv(file.path(OUT, "validation_web_comparison.csv"), show_col_types = FALSE) |>
  filter(program_status == "current", mobile_flag == "no")
message("core agencies: ", nrow(v))
edges <- c(0, 1, 2, 5, 10, 20, 50, 100, 200, 500, Inf)
rng <- tibble(lo = head(edges, -1), hi = tail(edges, -1)) |> mutate(i = row_number(),
  lab = case_when(hi == Inf ~ paste0(lo, "+"), hi - lo == 1 ~ as.character(lo), TRUE ~ paste0(lo, "-", hi - 1)))
SER <- c("Publicly reported" = "#2a78d6", "Mapped in OSM (located in area)" = "#eb6834")
d <- bind_rows(tibble(series = names(SER)[1], n = v$reported), tibble(series = names(SER)[2], n = v$osm_located)) |>
  mutate(i = findInterval(n, edges, rightmost.closed = FALSE)) |>
  count(series, i) |> group_by(series) |> mutate(share = n / sum(n)) |> ungroup() |>
  complete(series, i = rng$i, fill = list(n = 0, share = 0)) |>
  mutate(series = factor(series, levels = names(SER)), x = i + if_else(series == names(SER)[1], -0.21, 0.21))
stopifnot(all(d |> group_by(series) |> summarise(t = sum(n)) |> pull(t) == nrow(v)))

st <- bind_rows(lapply(names(SER), \(s) { z <- if (s == names(SER)[1]) v$reported else v$osm_located
  tibble(series = s, stat = c("median", "mean"), value = c(median(z), mean(z))) }))
pos_x <- function(val) { k <- max(which(rng$lo <= val)); b <- rng[k, ]
  if (b$lo == 0) return(k)
  hi <- if (is.finite(b$hi)) b$hi else 1000; k - 0.5 + (log(val) - log(b$lo)) / (log(hi) - log(b$lo)) }
st <- st |> mutate(x = map_dbl(value, pos_x), series = factor(series, levels = names(SER)),
                   label = sprintf("%s %s: %s", if_else(series == names(SER)[1], "Reported", "OSM"), stat,
                                   ifelse(value == round(value), sprintf("%.0f", value), sprintf("%.1f", value))),
                   y = max(d$share) * c(1.30, 1.22, 1.14, 1.06)[row_number()])
print(st)

p <- ggplot(d) +
  geom_col(aes(x = x, y = share, fill = series), width = 0.4) +
  geom_segment(data = st, aes(x = x, xend = x, y = 0, yend = y, colour = series), linetype = "dashed", linewidth = 0.5) +
  geom_text(data = st, aes(x = x + 0.08, y = y, label = label), hjust = 0, vjust = 0.5, size = 3.1, colour = "#0b0b0b") +
  scale_fill_manual(values = SER, name = NULL) + scale_colour_manual(values = SER, guide = "none") +
  scale_x_continuous(breaks = rng$i, labels = rng$lab, expand = expansion(add = 0.3)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1), expand = expansion(mult = c(0, 0.04))) +
  labs(x = "Fixed license plate reader cameras per agency", y = "Share of agencies",
       title = sprintf("Cameras per agency, %d agencies with a publicly reported count", nrow(v)),
       subtitle = "Reported: agency websites, government documents and news quoting officials (2022-2026); current programs, fixed\ncameras the agency operates. OSM: cameras mapped in OpenStreetMap inside the same agencies' areas (pulled 2026-10-03).",
       caption = "Not a random sample: only agencies with cameras whose count was published. Dashed lines are placed within their range on a log scale.") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top", legend.justification = "left", panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"),
        plot.caption = element_text(colour = "#52514e", hjust = 0, size = 8.5))
ggsave(file.path(OUT, "hist_web_sample_reported_vs_osm.png"), p, width = 10, height = 6, dpi = 150)
