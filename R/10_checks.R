# Regression checks. Each case below was a confirmed error in the 2026-10-03 audit memo
# (AUDIT_MEMO_2026-10-03.md). The script stops on the first failure.
source("R/00_setup.R")

c <- read_csv(file.path(OUT, "cameras.csv"), col_types = cols(.default = "c"))
a <- read_csv(file.path(OUT, "agencies.csv"), col_types = cols(.default = "c")) |>
  mutate(across(c(starts_with("cameras_"), starts_with("flock_")), as.integer))
ok <- 0
check <- function(cond, msg) {
  if (!isTRUE(cond)) stop("CHECK FAILED: ", msg, call. = FALSE)
  ok <<- ok + 1; message("  ok: ", msg)
}
ag <- function(o) a[a$ori == o, ]

# integrity
check(!anyDuplicated(c$osm_id), "camera ids unique")
check(!anyDuplicated(a$ori), "agency ORIs unique")
for (p in list(c("a_ori", "cameras_tagged"), c("b_ori", "cameras_located"), c("attr_ori", "cameras_attributed"))) {
  k <- c |> filter(!is.na(.data[[p[1]]])) |> count(ori = .data[[p[1]]])
  m <- a |> select(ori, saved = all_of(p[2])) |> left_join(k, by = "ori") |> mutate(n = coalesce(n, 0L))
  check(all(m$saved == m$n), paste(p[2], "reconciles with cameras.csv"))
}
check(all(is.na(c$b_ori) | c$b_ori %in% a$ori[a$record_status != "historical"]), "no camera located in a historical ORI")

# 1. other public operators are not credited to the local PD
check(!any(c$b_name %in% "New York City Police Department" &
             str_detect(coalesce(c$operator, ""), regex("department of transportation|d\\.o\\.t", ignore_case = TRUE))),
      "NYC DOT cameras not located to NYPD")
check(all(c$op_class[c$operator %in% c("California Highway Patrol (CHP)", "Customs and Border Protection",
                                       "University of Arizona Police Department")] == "public_other"),
      "CHP, CBP, University of Arizona PD classed public_other")

# 2. shared place code: Ocean City / Ocean Pines (MD)
oc <- c |> filter(place_geoid %in% "2458225", !is.na(b_ori))
check(nrow(oc) > 0 && all(oc$b_ori == "MD0240200"), "cameras inside Ocean City (2458225) go to Ocean City PD, not Ocean Pines")

# 2. missing county code: St. Charles County PD (MO)
check(ag("MO0922400")$county_fips == "29183" && ag("MO0922400")$cameras_located > 0,
      "St. Charles County PD has county 29183 and located cameras")

# 3. private filter
check(all(c$op_class[c$operator %in% c("University Heights PD", "North College Hill PD")] == "local_police") &&
        all(!is.na(c$b_ori[c$operator %in% c("University Heights PD", "North College Hill PD")])),
      "University Heights PD and North College Hill PD cameras are local police, not excluded")
check(all(c$op_class[c$operator %in% c("Meijer", "Kaiser Permanente", "Dierbergs Markets")] == "private") &&
        all(is.na(c$b_ori[c$operator %in% c("Meijer", "Kaiser Permanente", "Dierbergs Markets")])),
      "Meijer, Kaiser Permanente, Dierbergs excluded as private")

# 4. historical ORI: Jacksonville
check(ag("FL0160200")$record_status == "historical" && ag("FL0160200")$cameras_located == 0,
      "FL0160200 'Jacksonville' (last reported 2020) is historical and gets no cameras")
check(ag("FL0160000")$cameras_located > 0, "Jacksonville Sheriff's Office gets the Jacksonville cameras")
check(all(a$agency_type[str_detect(a$name, regex("sheriff", ignore_case = TRUE))] == "Sheriff"),
      "every agency named 'Sheriff' is typed Sheriff")

# 5. Town of Groton -> Groton Town PD
g <- c |> filter(operator %in% "Town of Groton Police Department")
check(nrow(g) > 0 && all(g$a_ori == "CT00A5900"), "'Town of Groton Police Department' matches Groton Town PD (CT00A5900)")

message(sprintf("\nAll %d checks passed.", ok))
