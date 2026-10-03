# Run the whole pipeline from the repo root, in order. Each script's log goes to output/log_<script>.txt.
#   Rscript R/run_all.R            # OSM from the committed snapshot (reproduces the published numbers)
#   Rscript R/run_all.R --pull     # new Overpass pull instead (~2 h; gives a new snapshot date)
#   Rscript R/run_all.R --from 03  # skip the downloads; start at script 03
# Set LC_ALL=C.UTF-8 before running (some regexes use non-ASCII characters).
args <- commandArgs(trailingOnly = TRUE)
osm <- if ("--pull" %in% args) "02_pull_osm" else "02_load_osm_snapshot"
steps <- c("01_download_census", osm, "03_agencies", "04_method_a", "05_operator_class", "06_method_b",
           "07_combine_outputs", "08_validate_portal", "09_validate_web", "10_hist_stats", "11_hist_web_sample",
           "12_summary", "13_checks", "14_manifest")
if ("--from" %in% args) steps <- steps[substr(steps, 1, 2) >= args[which(args == "--from") + 1]]
for (s in steps) {
  message("running ", s)
  log <- file.path("output", paste0("log_", s, ".txt"))
  if (system2("Rscript", file.path("R", paste0(s, ".R")), stdout = log, stderr = log) != 0)
    stop("FAILED: ", s, " (see ", log, ")")
}
message("done")
