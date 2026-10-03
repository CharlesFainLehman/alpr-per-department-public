# Write output/run_manifest.txt: input checksums, OSM snapshot, package versions, git commit.
# Raw inputs are not in git (size); the checksums identify the exact files a run used.
# The committed OSM snapshot (data/snapshots/) is included so a snapshot-based run is identified too.
source("R/00_setup.R")
library(digest)

raw_files <- list.files(RAW, recursive = TRUE, full.names = TRUE)
raw_files <- raw_files[!str_detect(raw_files, "/private_eyes/repo/\\.git/|\\.rds$")]
raw_files <- c(raw_files, list.files(file.path(ROOT, "data", "snapshots"), full.names = TRUE))   # committed OSM snapshot
sums <- tibble(file = str_remove(raw_files, paste0("^", ROOT, "/")),
               bytes = file.size(raw_files),
               sha256 = vapply(raw_files, \(f) digest(file = f, algo = "sha256"), ""))
pull_date <- readLines(file.path(PROC, "osm_pull_date.txt"))
ql <- read_csv(list.files(file.path(RAW, "osm", pull_date), "query_log.csv", full.names = TRUE), show_col_types = FALSE)
commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA)
pkgs <- c("sf", "dplyr", "readr", "tidyr", "stringr", "purrr", "jsonlite", "httr2", "stringdist", "ggplot2", "digest")

out <- c(
  sprintf("Run manifest written %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  sprintf("Git commit at run time: %s", commit),
  sprintf("OSM pull date: %s; Overpass osm_base timestamps %s to %s; endpoints: %s", pull_date,
          min(ql$osm_base), max(ql$osm_base), paste(unique(ql$endpoint), collapse = " | ")),
  sprintf("Camera rows: %s", nrow(readRDS(file.path(PROC, "osm_alpr.rds")))),
  sprintf("R: %s; GEOS/GDAL/PROJ: %s", R.version.string, paste(sf::sf_extSoftVersion()[c("GEOS", "GDAL", "PROJ")], collapse = " / ")),
  "Packages:", paste0("  ", pkgs, " ", vapply(pkgs, \(p) as.character(packageVersion(p)), "")),
  "", "Input files (sha256):", paste0("  ", sums$sha256, "  ", format(sums$bytes, big.mark = ","), "  ", sums$file))
writeLines(out, file.path(OUT, "run_manifest.txt"))
message("Wrote output/run_manifest.txt (", nrow(sums), " input files)")
