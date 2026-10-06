# Run the whole pipeline from the repo root, in order. Each script's log goes to output/log_<script>.txt.
#   Rscript R/run_all.R            # from the committed snapshots (reproduces the published numbers)
#   Rscript R/run_all.R --pull     # first make a new OSM snapshot from the live database (~2 h)
#   Rscript R/run_all.R --from 04  # start at script 04 (01-03 already run)
Sys.setenv(LC_ALL = "C.UTF-8")   # some regexes use non-ASCII characters; inherited by each Rscript below
args <- commandArgs(trailingOnly = TRUE)
steps <- c("01_census", if ("--pull" %in% args) "osm_pull", "02_osm_snapshot", "03_agencies", "04_match_operator_names",
           "05_classify_operators", "06_locate_cameras", "07_count_per_agency", "08_validate", "09_charts")
if ("--from" %in% args) steps <- steps[seq(which(substr(steps, 1, 2) == args[which(args == "--from") + 1])[1], length(steps))]
for (s in steps) {
  message("running ", s)
  log <- file.path("output", paste0("log_", s, ".txt"))
  if (system2("Rscript", file.path("R", paste0(s, ".R")), stdout = log, stderr = log) != 0)
    stop("FAILED: ", s, " (see ", log, ")")
}
message("done")
