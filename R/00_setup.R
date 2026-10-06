# Shared paths, packages, and helpers. Sourced by every other script.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(jsonlite)
  library(sf)
})

# Scripts are run as `Rscript R/xx.R` from the repo root (R/run_all.R runs them all in order).
ROOT <- normalizePath(".")
stopifnot(dir.exists(file.path(ROOT, "R")))

RAW  <- file.path(ROOT, "data", "raw")
PROC <- file.path(ROOT, "data", "derived")
OUT  <- file.path(ROOT, "output")
OUT_PNG <- file.path(OUT, "png")   # charts
OUT_CSV <- file.path(OUT, "csv")   # tables
REVIEW <- file.path(OUT, "review")   # diagnostic lists for manual review
for (d in c(RAW, PROC, OUT, OUT_PNG, OUT_CSV, REVIEW)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

TIGER_YEAR <- 2025   # latest TIGER/Line on www2.census.gov at download time
ACS_YEAR   <- 2024   # latest ACS 5-year (2020-2024)
LEE_FILE   <- "lee_1960_2025.csv"

# 50 states + DC (no territories: DeFlock/ALPR focus and LEAIC coverage are US states)
STATES <- tibble::tribble(
  ~abbr, ~fips, ~name,
  "AL","01","Alabama","AK","02","Alaska","AZ","04","Arizona","AR","05","Arkansas",
  "CA","06","California","CO","08","Colorado","CT","09","Connecticut","DE","10","Delaware",
  "DC","11","District of Columbia","FL","12","Florida","GA","13","Georgia","HI","15","Hawaii",
  "ID","16","Idaho","IL","17","Illinois","IN","18","Indiana","IA","19","Iowa",
  "KS","20","Kansas","KY","21","Kentucky","LA","22","Louisiana","ME","23","Maine",
  "MD","24","Maryland","MA","25","Massachusetts","MI","26","Michigan","MN","27","Minnesota",
  "MS","28","Mississippi","MO","29","Missouri","MT","30","Montana","NE","31","Nebraska",
  "NV","32","Nevada","NH","33","New Hampshire","NJ","34","New Jersey","NM","35","New Mexico",
  "NY","36","New York","NC","37","North Carolina","ND","38","North Dakota","OH","39","Ohio",
  "OK","40","Oklahoma","OR","41","Oregon","PA","42","Pennsylvania","RI","44","Rhode Island",
  "SC","45","South Carolina","SD","46","South Dakota","TN","47","Tennessee","TX","48","Texas",
  "UT","49","Utah","VT","50","Vermont","VA","51","Virginia","WA","53","Washington",
  "WV","54","West Virginia","WI","55","Wisconsin","WY","56","Wyoming"
)

# Print row counts at every join / filter step.
n_log <- function(df, label) {
  message(sprintf("[rows] %-60s %s", label, format(nrow(df), big.mark = ",")))
  invisible(df)
}

# Download once; keep the file. Returns the path.
fetch <- function(url, dest, tries = 4) {
  if (file.exists(dest) && file.size(dest) > 0) return(dest)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(tries)) {
    ok <- tryCatch({
      utils::download.file(url, dest, mode = "wb", quiet = TRUE, method = "libcurl")
      TRUE
    }, error = function(e) { message("  download failed (", i, "): ", conditionMessage(e)); FALSE })
    if (ok && file.size(dest) > 0) return(dest)
    Sys.sleep(2^i)
  }
  stop("Could not download ", url)
}

# Agencies that receive cameras (03_agencies.R sets record_status; contract cities and historical ORIs don't).
is_current <- function(record_status) record_status %in% c("current_cde", "employee_file_only_recent")

# Newest committed snapshot for a prefix, e.g. latest_snapshot("osm_alpr_raw") ->
# "data/snapshots/osm_alpr_raw_2026-10-03.csv.gz". NA if there is none.
latest_snapshot <- function(prefix) {
  f <- sort(list.files("data/snapshots", paste0("^", prefix, "_\\d{4}-\\d{2}-\\d{2}\\.csv\\.gz$"), full.names = TRUE),
            decreasing = TRUE)
  if (length(f)) f[1] else NA_character_
}
snapshot_date <- function(path) str_match(basename(path), "_(\\d{4}-\\d{2}-\\d{2})\\.csv\\.gz$")[, 2]
