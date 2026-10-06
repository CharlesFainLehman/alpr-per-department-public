# Captures per day of one vehicle in ALPR Fourth Amendment rulings, against the Carpenter benchmark.
# Standalone (not in run_all.R): reads the hand-built docs/alpr_observation_counts.xlsx.
# Only records spanning a week or more (the sheet leaves shorter ones without a period) and only
# figures from the court record (press rows, tier "c", are left out).
source("R/00_setup.R")
source("R/theme_cf.R")

x <- readxl::read_excel("docs/alpr_observation_counts.xlsx", sheet = "Observation counts")
n_log(x, "cases in spreadsheet")
d <- x |>
  transmute(case = Case, outcome = Outcome, tier = `Source tier`,
            n = `Captures (count)`, days = `Period (days)`) |>
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
cf_save(p, file.path(OUT, "court_observations_per_day.png"))
