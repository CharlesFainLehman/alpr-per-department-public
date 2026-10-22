# alpr-per-department

Ties crowdsourced OpenStreetMap camera data (the DeFlock layer) to US local police agencies, checks the mapped
counts against publicly reported ones, and compares observation counts in ALPR court rulings with *Carpenter*.
Method write-up: `docs/METHODS.md`. Step-by-step guide to the code: `docs/HOW_IT_WORKS.md`.

## Charts

| Chart | What it shows |
|---|---|
| `output/png/validation_web_scatter.png` | reported vs. mapped cameras, 360 agencies |
| `output/png/hist_cameras_per_agency_stats.png` | all 7,795 agencies with a mapped camera: share by number of cameras (median 6) |
| `output/png/hist_reported_cameras_per_agency.png` | the validation agencies: share by number of cameras they reported (median 17) |
| `output/png/hist_findingflock_public_operators.png` | Finding Flock's public operators: share by number of operator-tagged cameras (median 11) |
| `output/png/court_observations_per_day.png` | captures per day in ALPR court rulings vs. *Carpenter* |

All five are drawn by `R/09_charts.R` from files in git, so `Rscript R/09_charts.R` redraws them without rerunning
the pipeline: `output/csv/validation_web_comparison.csv` (one row per agency), `output/csv/validation_web_metrics.csv`,
`output/csv/agencies.csv` and `docs/alpr_observation_counts.xlsx` (court rulings, compiled by hand with sources).

## Pipeline

| Script | Does |
|---|---|
| `R/01_census.R` | downloads Census TIGER/Line 2025 boundaries and ACS 2020-24 population |
| `R/02_osm_snapshot.R` | loads the committed OpenStreetMap snapshot (143,157 cameras, 2026-10-03) |
| `R/03_agencies.R` | builds the list of local police and sheriff's offices (FBI directory, FBI employee file, BJS LEAIC) |
| `R/04_match_operator_names.R` | matches each camera's operator tag to an agency name |
| `R/05_classify_operators.R` | classes each operator: local agency, vendor, private, other public body, ... |
| `R/06_locate_cameras.R` | credits each camera to the local agency its operator tag names, or else the agency whose area contains it; excludes private, other-public and non-operating cameras |
| `R/07_count_per_agency.R` | per-camera and per-agency tables, summary statistics |
| `R/08_validate.R` | compares located counts with reported counts (and Minnesota's register) |
| `R/09_charts.R` | the five charts |
| `R/osm_pull.R` | optional: makes a new OSM snapshot from the live database (~2 h) |
| `R/findingflock_pull.R` | optional: snapshots the operator tables on findingflock.com/operators |

Shared: `R/00_setup.R` (paths, helpers), `R/name_parser.R` (agency-name normalization), `R/theme_cf.R` (chart style).

## Data

| Path | Contents |
|---|---|
| `data/snapshots/` | OSM snapshot and its Overpass query log; FBI agency directory and employee file, pinned 2026-10-06; Finding Flock operator table, 2026-10-07 (derived from OpenStreetMap) |
| `data/validation_web/` | publicly reported camera counts (URL and quote per row), status overrides, Minnesota BCA register |
| `data/operator_class_overrides.csv` | reviewed operator classes that override the rules in 05 |
| `data/fonts/` | Liberation Sans, the chart font (SIL Open Font License) |

Census files are downloaded on the first run (~0.5 GB, `data/raw/`, not in git). The BJS crosswalk (LEAIC 2012,
ICPSR 35158) is not in git either, because ICPSR's terms bar redistributing it: download DS1 (free ICPSR login) from
https://www.icpsr.umich.edu/web/NACJD/studies/35158 and put `35158-0001-Data.tsv` (or `.rda`) in `data/raw/leaic/`
before the first run. Intermediate files go to
`data/derived/` and lists for manual review to `output/review/`. Of the tables in `output/csv/`, all are in git except
`cameras.csv.gz` (one row per camera, 4 MB), which a run writes.

## Rerunning

```
Rscript R/run_all.R            # from the committed snapshots and LEAIC; reproduces the published numbers (~2 min after downloads)
Rscript R/run_all.R --from 04  # skip 01-03 when they have already run
Rscript R/run_all.R --pull     # make a new OSM snapshot first
```

R packages: sf, dplyr, readr, tidyr, stringr, stringi, purrr, jsonlite, httr2, stringdist, ggplot2, scales, ragg,
systemfonts, readxl (and xml2 for `R/findingflock_pull.R`). Logs go to `output/log_<script>.txt`.

## Known limits

- 84% of OSM cameras have no operator tag. Untagged cameras of other operators inside an agency's area count for that agency.
  So nearly every mapped camera is credited to some agency, each to one only: 135,872 of 143,159 (95%, counting
  `camera:count`). Only cameras tagged to a private party or another public body, tagged as not operating, or outside
  any local agency's area are left out. The validation's median ratio of mapped to reported cameras (1.14; 2.05 for
  agencies serving 250,000+) is consistent with these cameras inflating the counts, most in big cities.
- Some reported counts are old (24 of the 360 predate 2025) or cover a different scope; `08` reports the metrics for
  sources dated 2025-2026 separately, and rows counting locations rather than cameras are kept out of the core set.
- In `agencies.csv`, `area_resolved = FALSE` marks agencies with no mapped service area (150); their zero is not a mapped zero.
- Volunteer mapping coverage is uneven, and car-mounted readers are not in OSM.
- Cities that pay the county sheriff for policing are listed in the FBI directory as police departments. 03 drops
  them when they report no staff (in California, or with an ORI ending in "X"), so their cameras go to the sheriff.
  Contract cities that report staff under the city's own ORI (Broward County, FL; King County, WA) are not caught.
- Some reported sheriff counts include contract cities' cameras and some don't (San Mateo County's excludes two).
  The comparison doesn't adjust for this.
- LEAIC is from 2012, so newer agencies are matched by name, and a few codes are corrected in 03 and 06.
- Agencies with a published count are not a random sample.

## Licenses

The camera data are © OpenStreetMap contributors, available under the Open Database License
(https://www.openstreetmap.org/copyright). The OSM snapshot, the Finding Flock table, and the tables in `output/csv/`
built from them are released under the same license. The FBI and Census files are US government works. Liberation
Sans is under the SIL Open Font License (`data/fonts/LICENSE-LiberationSans`).
