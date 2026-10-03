# alpr-per-department

Estimate the number of automated license plate readers (ALPRs) per US police
department. The method crosswalks crowdsourced OpenStreetMap camera data (the
DeFlock layer) to law-enforcement agencies.

Status: complete run on the 2026-10-03 OSM pull. Results in `output/summary.md`. Task spec in `PROMPT.md`.

## Layout

- `PROMPT.md` - task specification for Claude Code
- `R/` - analysis scripts
- `data/raw/` - raw downloads (not tracked in git)
- `data/derived/` - cleaned and joined files
- `output/` - tables, plots, summary

## Data sources

- OpenStreetMap nodes tagged `man_made=surveillance` and
  `surveillance:type=ALPR` (Overpass API or Geofabrik extract)
- BJS Law Enforcement Agency Identifiers Crosswalk (LEAIC)
- FBI agency participation file
- Census TIGER/Line boundaries and ACS 5-year population
- The News & Observer, "Private Eyes" Flock transparency portal data
  (https://github.com/mcclatchy-southeast/private_eyes), used for validation

## Known limits

- Many OSM cameras have no operator tag.
- A spatial join assigns private, sheriff, and state cameras inside city
  limits to the local police department.
- Volunteer coverage is uneven across areas.
- LEAIC is old; newer agencies are missing.

## Run order (from the repo root)

```
Rscript R/01_download_census.R      # TIGER/Line 2025 states, counties, places, county subdivisions; ACS 2020-24 B01003
Rscript R/02_pull_osm.R             # Overpass, state by state -> data/raw/osm/<date>/, osm_alpr_raw_<date>.csv
Rscript R/03_agencies.R             # FBI CDE directory + FBI employee file + LEAIC; record_status, county fallback
Rscript R/04_method_a.R             # tagged: operator-tag name match
Rscript R/04b_operator_class.R      # operator class for every camera (private / public_other / local / vendor ...)
Rscript R/05_method_b.R             # located: spatial assignment with per-camera b_status
Rscript R/06_combine_outputs.R      # cameras.csv, agencies.csv (tagged / located / attributed), summary_stats.csv, density plot
Rscript R/07_validate.R             # historical comparison with N&O Flock portal counts
Rscript R/08_summary.R              # output/summary.md
Rscript R/09_density_stats.R        # density of located cameras with mean, median, 99th percentile lines
Rscript R/10_checks.R               # regression checks from the 2026-10-03 audit
Rscript R/11_manifest.R             # output/run_manifest.txt: input checksums, OSM snapshot, package versions
Rscript R/operator_counts.R         # optional: cameras per operator name (no agency matching)
```

Measures and their limits are defined at the top of `output/summary.md`. Audit and response:
`AUDIT_MEMO_2026-10-03.md`, `AUDIT_RESPONSE.md`. Court cases: `output/court_cases.md`.

R packages: sf, dplyr, readr, tidyr, stringr, purrr, jsonlite, httr2, stringdist, ggplot2, digest.

## Manual download: LEAIC (needed for method B)

ICPSR needs a login and blocks scripted access. Download by hand:
https://www.icpsr.umich.edu/web/NACJD/studies/35158 -> DS1, Delimited (or R) format.
Put `35158-0001-Data.tsv` (or `.rda`) under `data/raw/leaic/`, then re-run from `03_agencies.R`.

## Access notes

- Overpass: `overpass-api.de` is tried first, the `maps.mail.ru` mirror second (same Overpass
  software, live OSM data). The endpoint and OSM timestamp per state are in `data/raw/osm/<date>/query_log.csv`.
- FBI: agency directory from `cde.ucr.cjis.gov/LATEST/agency/byStateAbbr/<ST>`; population served
  from the CDE "Law Enforcement Employees" file (`lee_1960_2025.csv`), latest year per ORI.
- ACS: summary-file download (`acsdt5y2024-b01003.dat`); the Census API now requires a key.
- Validation file is dated 2024-04-26 in its `updated` field, despite "2023" in the file name.
