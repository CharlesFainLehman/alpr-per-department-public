# Causal Fallacy house chart style (verbatim spec). Sourced by every script that draws a chart.
# Needs the ragg package. Charts pass x = NULL, y = NULL.
library(ggplot2)
library(scales)

# Liberation Sans ships in data/fonts/ (SIL Open Font License); register it when it isn't installed.
if (!"Liberation Sans" %in% systemfonts::system_fonts()$family)
  systemfonts::register_font("Liberation Sans", plain = "data/fonts/LiberationSans-Regular.ttf",
                             bold = "data/fonts/LiberationSans-Bold.ttf")

cf_ink    <- "#111111"
cf_mute   <- "#8A8A8A"
cf_grid   <- "#E8E8E8"
cf_axis   <- "#5A5A5A"
cf_sub    <- "#7A7A7A"
cf_orange <- "#E8532B"
cf_blue   <- "#1F77D0"

theme_cf <- function(title_size = 36) {
  theme_minimal(base_family = "Liberation Sans", base_size = 20) +
    theme(
      plot.background    = element_rect(fill = "white", color = NA),
      panel.background   = element_rect(fill = "white", color = NA),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = cf_grid, linewidth = 0.6),
      axis.text          = element_text(color = cf_axis, size = 21),
      axis.ticks         = element_blank(),
      plot.title         = element_text(face = "bold", size = title_size,
                                        color = cf_ink, margin = margin(b = 10)),
      plot.subtitle      = element_text(size = 21, color = cf_sub,
                                        margin = margin(b = 34)),
      plot.caption       = element_text(size = 15, color = cf_mute, hjust = 0,
                                        lineheight = 1.25, margin = margin(t = 26)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      plot.margin        = margin(36, 40, 26, 30)
    )
}

cf_caption <- function(source) {
  paste0("Source: ", source, "\nChart created with the help of Claude.")
}

cf_save <- function(p, path) {
  ggsave(path, p, device = ragg::agg_png,
         width = 1600, height = 900, units = "px", dpi = 100, bg = "white")
}
