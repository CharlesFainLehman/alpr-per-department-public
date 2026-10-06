# Distribution of cameras per agency for the core web-validation agencies (current program, fixed,
# agency-operated count): publicly reported count vs. OSM cameras located in the same agencies' areas.
source("R/00_setup.R")
source("R/theme_cf.R")

v <- read_csv(file.path(OUT_CSV, "validation_web_comparison.csv"), show_col_types = FALSE) |>
  filter(program_status == "current", mobile_flag == "no")
message("core agencies: ", nrow(v))
edges <- c(0, 1, 2, 5, 10, 20, 50, 100, 200, 500, Inf)
rng <- tibble(lo = head(edges, -1), hi = tail(edges, -1)) |> mutate(i = row_number(),
  lab = case_when(hi == Inf ~ paste0(lo, "+"), hi - lo == 1 ~ as.character(lo), TRUE ~ paste0(lo, "-", hi - 1)))
SER <- c("Publicly reported" = cf_blue, "Mapped in OSM (located in area)" = cf_orange)
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

st <- st |> filter(stat == "median") |>
  mutate(label = sprintf("%s median: %s", if_else(series == names(SER)[1], "Reported", "Mapped"), sprintf("%.0f", value)))
ymax <- ceiling(max(d$share) * 1.25 * 20) / 20
st$y <- ymax * c(0.97, 0.88)
p <- ggplot(d) +
  geom_col(aes(x = x, y = share, fill = series), width = 0.4) +
  geom_segment(data = st, aes(x = x, xend = x, y = 0, yend = y, colour = series), linetype = "dashed", linewidth = 1) +
  geom_text(data = st, aes(x = x + 0.1, y = y, label = label, colour = series), hjust = 0, vjust = 0.5,
            family = "Liberation Sans", size = 21 / .pt) +
  scale_fill_manual(values = SER, guide = "none") + scale_colour_manual(values = SER, guide = "none") +
  scale_x_continuous(breaks = rng$i, labels = rng$lab, expand = expansion(add = 0.3)) +
  scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, ymax), expand = expansion(mult = c(0, 0))) +
  labs(x = NULL, y = NULL,
       title = "Reported and mapped camera counts look much alike",
       subtitle = sprintf("Share of %d agencies by number of fixed license plate reader cameras: count reported by the agency (blue)\nand cameras mapped in OpenStreetMap in its area (orange). Not a random sample: all have a published count.", nrow(v)),
       caption = cf_caption(sprintf("Agency websites, government documents and news reports (%s-%s); OpenStreetMap via Overpass, pulled %s.",
                                    min(substr(v$as_of_date, 1, 4)), max(substr(v$as_of_date, 1, 4)), readLines(file.path(PROC, "osm_pull_date.txt"))))) +
  theme_cf(title_size = 36)
cf_save(p, file.path(OUT_PNG, "hist_web_sample_reported_vs_osm.png"))
