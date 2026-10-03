# Density of cameras per agency (method B) with a reference line at the largest ALPR network a court
# has held is not a Fourth Amendment search.
#
# Scholl v. Illinois State Police, No. 1:24-cv-04435 (N.D. Ill. Mar. 31, 2025) (Pacold, J.), Doc. 41:
# "the Illinois State Police has installed 344 cameras in Cook County, 78 in St. Clair County, and 44
# across 17 other counties" = 466. Held: not a search. (Appeal argued in the 7th Cir., Sept. 2026.)
# For comparison, Schmidt v. City of Norfolk (E.D. Va. Jan. 27, 2026) involved Norfolk's 176 cameras.
source("R/00_setup.R")
library(ggplot2)

# Two reference networks, both held not to be a Fourth Amendment search:
#  - United States v. Sturdivant, No. 1:22-cr-615 (N.D. Ohio June 9, 2025) (Calabrese, J.), Doc. 103 at 5:
#    "There are 1,636 Flock cameras across Cuyahoga County, 667 of which are associated with law
#    enforcement agencies." (Plus ~1,119 ELSAG cameras; the court puts the total at "approximately
#    1,800 to 3,000 cameras".) Suppression ruling on police queries; largest network any upholding court described.
#  - Scholl v. Illinois State Police (N.D. Ill. 2025): 466 ISP cameras; largest network whose collection
#    itself was challenged in a civil suit and held not a search.
CUTS <- tibble(n = c(466, 1636),
               case = c("Scholl v. Illinois State Police\n(N.D. Ill. 2025): 466 cameras",
                        "U.S. v. Sturdivant\n(N.D. Ohio 2025): 1,636 cameras"))
ags <- read_csv(file.path(OUT, "agencies.csv"), show_col_types = FALSE)
ags <- ags |> filter(record_status != "historical")
pos <- ags |> filter(cameras_located >= 1)
CUTS <- CUTS |> mutate(below_pos = map_int(n, \(k) sum(pos$cameras_located < k)), above = map_int(n, \(k) sum(ags$cameras_located >= k)),
                       below_all = map_int(n, \(k) sum(ags$cameras_located < k)))
for (i in seq_len(nrow(CUTS))) message(sprintf("Below %d: %d of %d agencies with >=1 camera (%.2f%%); %d of %d all (%.2f%%); at/above: %d",
  CUTS$n[i], CUTS$below_pos[i], nrow(pos), 100 * CUTS$below_pos[i] / nrow(pos), CUTS$below_all[i], nrow(ags),
  100 * CUTS$below_all[i] / nrow(ags), CUTS$above[i]))
CUTS <- CUTS |> mutate(short = c("Scholl v. Illinois State Police (N.D. Ill. 2025): 466",
                                  "U.S. v. Sturdivant (N.D. Ohio 2025): 1,636"))
cap <- sprintf(paste0("Dashed lines: camera counts of networks courts held were not a Fourth Amendment search.\n",
  "Fewer mapped cameras in their area than 466: %s of %s agencies (%.1f%%); than 1,636: %s of %s (%.2f%%).\n",
  "NOT like-for-like. Court figures count one specific network (Scholl: one state agency's cameras; Sturdivant: a county-wide pool of\n",
  "many owners' cameras). OSM counts are mapped cameras located in an agency's area, mapping is incomplete, and agencies can\n",
  "search cameras far beyond their area through shared networks. This chart does not show that agencies' networks are smaller."),
  format(CUTS$below_pos[1], big.mark = ","), format(nrow(pos), big.mark = ","), 100 * CUTS$below_pos[1] / nrow(pos),
  format(CUTS$below_pos[2], big.mark = ","), format(nrow(pos), big.mark = ","), 100 * CUTS$below_pos[2] / nrow(pos))
CUTS <- CUTS |> mutate(lab = sprintf("%s\nheld not a search.\n%s of %s agencies below (%.2f%%);\n%d at or above.",
  case, format(below_pos, big.mark = ","), format(nrow(pos), big.mark = ","), 100 * below_pos / nrow(pos), above))

p <- ggplot(pos, aes(cameras_located)) +
  geom_density(colour = "#eb6834", fill = "#eb6834", alpha = 0.15, linewidth = 0.8, adjust = 1.2) +
  geom_vline(data = CUTS, aes(xintercept = n), colour = "#0b0b0b", linewidth = 0.6, linetype = "dashed") +
  geom_text(data = CUTS, aes(x = n * 0.92, y = 0.68, label = short), angle = 90, hjust = 1, vjust = 0, size = 3.1,
            colour = "#0b0b0b") +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 466, 1636),
                labels = c("1", "2", "5", "10", "20", "50", "100", "200", "466", "1,636")) +
  labs(x = "License plate reader cameras located in agency's area, mapped in OpenStreetMap (log scale)", y = "Density",
       title = "Mapped ALPRs in each agency's area, with camera counts from two court cases for reference",
       subtitle = sprintf("Local police and sheriffs with at least one camera mapped in OpenStreetMap (OSM), the crowdsourced map\nused by DeFlock. Cameras located in the agency's area, excluding other operators (n = %s agencies). Data pulled %s.",
                          format(nrow(pos), big.mark = ","), readLines(file.path(PROC, "osm_pull_date.txt")))) +
  labs(caption = cap) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
        plot.background = element_rect(fill = "#fcfcfb", colour = NA), plot.subtitle = element_text(colour = "#52514e"),
        plot.title = element_text(colour = "#0b0b0b"),
        plot.caption = element_text(colour = "#52514e", hjust = 0, size = 8.5))
ggsave(file.path(OUT, "density_cameras_per_agency_court_cutoff.png"), p, width = 10, height = 6, dpi = 150)
