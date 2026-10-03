# Alternative to 02_pull_osm.R: rebuild the camera table from the committed snapshot instead of
# querying Overpass (a new pull gives a new snapshot and slightly different counts).
#   Rscript R/02_load_osm_snapshot.R            # newest snapshot in data/snapshots/
#   Rscript R/02_load_osm_snapshot.R 2026-10-03 # a specific date
source("R/00_setup.R")
args <- commandArgs(trailingOnly = TRUE)
snaps <- sort(list.files("data/snapshots", "^osm_alpr_raw_.*\\.csv\\.gz$"), decreasing = TRUE)
stopifnot(length(snaps) > 0)
PULL_DATE <- if (length(args)) args[1] else sub("^osm_alpr_raw_(.*)\\.csv\\.gz$", "\\1", snaps[1])
f <- file.path("data/snapshots", sprintf("osm_alpr_raw_%s.csv.gz", PULL_DATE))
cams <- read_csv(f, col_types = cols(.default = "c", lat = "d", lon = "d", osm_version = "i"), na = "NA", trim_ws = FALSE)
n_log(cams, paste("cameras in snapshot", PULL_DATE))
stopifnot(!anyDuplicated(cams$osm_id))
odir <- file.path(RAW, "osm", PULL_DATE); dir.create(odir, recursive = TRUE, showWarnings = FALSE)
file.copy(file.path("data/snapshots", sprintf("query_log_%s.csv", PULL_DATE)), file.path(odir, "query_log.csv"), overwrite = TRUE)
saveRDS(cams, file.path(PROC, "osm_alpr.rds"))
writeLines(PULL_DATE, file.path(PROC, "osm_pull_date.txt"))
mf <- cams |> mutate(manufacturer = coalesce(manufacturer, "(none)")) |> count(manufacturer, sort = TRUE)
write_csv(mf, file.path(OUT, "osm_counts_by_manufacturer.csv"))
message("Loaded snapshot ", PULL_DATE, ": ", nrow(cams), " cameras")
