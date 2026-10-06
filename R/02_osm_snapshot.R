# Load the OpenStreetMap camera snapshot: every node tagged man_made=surveillance + surveillance:type=ALPR
# in the 50 states and DC, as committed in data/snapshots/osm_alpr_raw_<date>.csv.gz.
#   Rscript R/02_osm_snapshot.R              # newest snapshot
#   Rscript R/02_osm_snapshot.R 2026-10-03   # a specific one
# R/osm_pull.R makes a new snapshot from the live OSM database (optional, ~2 h).
source("R/00_setup.R")
args <- commandArgs(trailingOnly = TRUE)
f <- if (length(args)) file.path("data/snapshots", sprintf("osm_alpr_raw_%s.csv.gz", args[1])) else latest_snapshot("osm_alpr_raw")
stopifnot(!is.na(f), file.exists(f))
PULL_DATE <- snapshot_date(f)

cams <- read_csv(f, col_types = cols(.default = "c", lat = "d", lon = "d", osm_version = "i"), na = "NA", trim_ws = FALSE)
n_log(cams, paste("cameras in snapshot", PULL_DATE))
stopifnot(!anyDuplicated(cams$osm_id))
message(sprintf("  with a non-empty operator tag: %.1f%%", 100 * mean(coalesce(str_squish(cams$operator) != "", FALSE))))

saveRDS(cams, file.path(PROC, "osm_alpr.rds"))
writeLines(PULL_DATE, file.path(PROC, "osm_pull_date.txt"))
