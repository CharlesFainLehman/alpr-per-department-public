# Put the camera-level results together and count the cameras located in each agency's area.
#
# An agency's "located" cameras (06_locate_cameras.R) are those its operator tag names, plus untagged cameras in its
# area; cameras tagged to a private party, another public body or another local agency, and cameras tagged as not
# operating, are left out. A node tagged camera:count = n counts n cameras. This is not an inventory of cameras an
# agency owns, and it says nothing about what an agency can search through shared networks.
#
# Writes output/csv/cameras.csv.gz (one row per camera), output/csv/agencies.csv (one row per agency,
# including agencies with no cameras) and output/csv/summary_stats.csv.
source("R/00_setup.R")

cams <- readRDS(file.path(PROC, "osm_alpr.rds"))
om   <- readRDS(file.path(PROC, "operator_match.rds"))
cls  <- readRDS(file.path(PROC, "operator_class.rds"))
loc  <- readRDS(file.path(PROC, "camera_location.rds"))
ag   <- readRDS(file.path(PROC, "agencies.rds"))
area <- readRDS(file.path(PROC, "agency_area.rds"))    # each agency's resolved area (06)

# Every intermediate must describe exactly this camera set.
for (d in list(om, cls, loc)) stopifnot(setequal(d$osm_id, cams$osm_id), !anyDuplicated(d$osm_id))

n_log(cams, "cameras")
x <- cams |> left_join(om, by = "osm_id") |> left_join(cls, by = "osm_id") |> left_join(loc, by = "osm_id")
stopifnot(nrow(x) == nrow(cams))
x <- x |>
  left_join(ag |> select(located_ori = ori, located_name = name, located_type = agency_type), by = "located_ori") |>
  # Flock camera: manufacturer or brand says Flock, or, with neither tagged, the operator does ("Flock Safety")
  mutate(is_flock = str_detect(str_to_lower(paste(manufacturer, brand)), "flock") |
           (is.na(manufacturer) & is.na(brand) & str_detect(str_to_lower(coalesce(operator, "")), "flock")),
         # an operator-name match is reported only where the operator is a local agency (an override can
         # reclass a matched name, e.g. "Texas DPS" is not Texas City PD)
         operator_ori = if_else(op_class %in% c("local_police", "local_government"), operator_ori, NA),
         devices = pmax(1L, coalesce(suppressWarnings(as.integer(str_match(all_tags, '"camera:count":"([0-9]+)"')[, 2])), 1L)))
n_log(x, "cameras with operator class, location and agency names")
saveRDS(x, file.path(PROC, "cameras_assigned.rds"))
write_csv(x |> select(osm_id, lat, lon, state, manufacturer, brand, operator, operator_type, surveillance,
                      surveillance_zone, last_edit, is_flock, devices, op_class, op_class_source, operator_ori, operator_match,
                      located_status, located_ori, located_name, located_type, place_geoid, cousub_geoid, county_geoid),
          gzfile(file.path(OUT_CSV, "cameras.csv.gz")))

# Agency table ------------------------------------------------------------------------------------------
INFERRED <- c("inferred_no_pd_in_place", "inferred_countywide_pd", "direct_place_name_mismatch", "direct_cousub_name_mismatch")
per_ag <- x |> filter(!is.na(located_ori)) |>
  summarise(cameras_located = sum(devices), located_via_inferred_rule = sum(devices[located_status %in% INFERRED]), .by = located_ori)
# LEAIC's own place codes are left out: ICPSR's terms bar redistributing the crosswalk.
agt <- ag |> select(ori, name, agency_type, state, record_status, county_fips, population_fbi, pop_year) |>
  left_join(area, by = "ori") |> relocate(area, .after = record_status) |>
  left_join(per_ag, by = c("ori" = "located_ori")) |>
  mutate(across(c(cameras_located, located_via_inferred_rule), \(v) coalesce(v, 0L)),
         per10k_located = if_else(population_fbi > 0, 1e4 * cameras_located / population_fbi, NA),
         # a zero for an agency with no resolved area is not a mapped zero
         area_resolved = !is.na(area))
n_log(agt, "agency table (all local PDs + sheriffs, incl. zero cameras)")
stopifnot(sum(agt$cameras_located) == sum(x$devices[!is.na(x$located_ori)]))
write_csv(agt, file.path(OUT_CSV, "agencies.csv"))

# Summary statistics (current agencies only; contract cities and historical ORIs never receive cameras) ---------
popbin <- function(p) cut(p, c(-Inf, 2500, 10000, 25000, 50000, 100000, 250000, Inf), right = FALSE,
                          labels = c("<2.5k", "2.5k-10k", "10k-25k", "25k-50k", "50k-100k", "100k-250k", "250k+"))
cur <- agt |> filter(is_current(record_status)) |>
  mutate(pop_bin = coalesce(as.character(popbin(population_fbi)), "unknown"))
stats <- function(d) d |> summarise(
  agencies = n(), cameras = sum(cameras_located), mean = mean(cameras_located), median = median(cameras_located),
  p10 = quantile(cameras_located, .10), p25 = quantile(cameras_located, .25), p75 = quantile(cameras_located, .75),
  p90 = quantile(cameras_located, .90), p99 = quantile(cameras_located, .99), max = max(cameras_located), .groups = "drop")
summ <- map_dfr(list("agencies with >=1 camera" = filter(cur, cameras_located >= 1), "all current agencies" = cur), \(d) bind_rows(
  stats(d) |> mutate(group_var = "overall", group = "all"),
  stats(group_by(d, group = agency_type)) |> mutate(group_var = "agency_type"),
  stats(group_by(d, group = pop_bin)) |> mutate(group_var = "population_bin")), .id = "set") |>
  relocate(set, group_var, group)
write_csv(summ, file.path(OUT_CSV, "summary_stats.csv"))
print(summ |> filter(group_var == "overall"), width = Inf)
