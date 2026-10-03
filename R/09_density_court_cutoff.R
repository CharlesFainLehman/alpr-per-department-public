# Density of cameras per agency (method B) with a reference line at the largest ALPR network a court
# has held is not a Fourth Amendment search.
#
# Scholl v. Illinois State Police, No. 1:24-cv-04435 (N.D. Ill. Mar. 31, 2025) (Pacold, J.), Doc. 41:
# "the Illinois State Police has installed 344 cameras in Cook County, 78 in St. Clair County, and 44
# across 17 other counties" = 466. Held: not a search. (Appeal argued in the 7th Cir., Sept. 2026.)
# For comparison, Schmidt v. City of Norfolk (E.D. Va. Jan. 27, 2026) involved Norfolk's 176 cameras.
source("R/00_setup.R")
library(ggplot2)

CUTOFF <- 466
ags <- read_csv(file.path(OUT, "agencies.csv"), show_col_types = FALSE)
pos <- ags |> filter(cameras_b >= 1)
below_all <- sum(ags$cameras_b < CUTOFF); below_pos <- sum(pos$cameras_b < CUTOFF)
message(sprintf("Below %d cameras: %d of %d agencies (%.2f%%); of agencies with >=1 camera: %d of %d (%.2f%%). At or above: %d.",
                CUTOFF, below_all, nrow(ags), 100 * below_all / nrow(ags), below_pos, nrow(pos),
                100 * below_pos / nrow(pos), sum(ags$cameras_b >= CUTOFF)))

lab <- sprintf("Scholl v. Illinois State Police\n(N.D. Ill. 2025): %d cameras,\nheld not a search\n\nBelow the line: %s of %s agencies (%.1f%%),\nor %.1f%% of all %s incl. zero mapped.\n%d agencies are at or above.",
               CUTOFF, format(below_pos, big.mark = ","), format(nrow(pos), big.mark = ","), 100 * below_pos / nrow(pos),
               100 * below_all / nrow(ags), format(nrow(ags), big.mark = ","), sum(ags$cameras_b >= CUTOFF))

p <- ggplot(pos, aes(cameras_b)) +
  geom_density(colour = "#eb6834", fill = "#eb6834", alpha = 0.15, linewidth = 0.8, adjust = 1.2) +
  geom_vline(xintercept = CUTOFF, colour = "#0b0b0b", linewidth = 0.6, linetype = "dashed") +
  annotate("text", x = CUTOFF * 0.85, y = Inf, label = lab, hjust = 1, vjust = 1.2, size = 3.1,
           colour = "#52514e", lineheight = 1.05) +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 466, 1000, 2000),
                labels = c("1", "2", "5", "10", "20", "50", "100", "200", "466", "1,000", "2,000")) +
  labs(x = "OSM ALPR cameras per agency, method B (log scale)", y = "Density",
       title = "Almost every agency's camera network is smaller than one a court has upheld",
       subtitle = sprintf("Local police and sheriffs with at least one mapped camera (n = %s). OSM pull %s.",
                          format(nrow(pos), big.mark = ","), readLines(file.path(PROC, "osm_pull_date.txt")))) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"),
        plot.title = element_text(colour = "#0b0b0b"))
ggsave(file.path(OUT, "density_cameras_per_agency_court_cutoff.png"), p, width = 9, height = 5, dpi = 150)
