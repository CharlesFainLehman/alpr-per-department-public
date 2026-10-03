# alpr-per-department

Estimate the number of automated license plate readers (ALPRs) per US police
department. The method crosswalks crowdsourced OpenStreetMap camera data (the
DeFlock layer) to law-enforcement agencies.

Status: complete run on the 2026-10-03 OSM pull. Results in `output/summary.md`. Task spec in `PROMPT.md`.
Work happens on branch `alpr-pipeline`. To rerun from scratch, see **Rerunning everything** below.

## Layout

- `PROMPT.md` - task specification for Claude Code
- `R/` - analysis scripts
- `data/raw/` - raw downloads (not tracked in git, except the LEAIC file)
- `data/snapshots/` - committed OSM snapshot (`osm_alpr_raw_<date>.csv.gz`) and its Overpass query log
- `data/validation_web/` - publicly reported camera counts collected from the web (one CSV per region/round)
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
#   or: Rscript R/02b_load_osm_snapshot.R [date]   # reuse the committed snapshot instead of a new pull
Rscript R/03_agencies.R             # FBI CDE directory + FBI employee file + LEAIC; record_status, county fallback
Rscript R/04_method_a.R             # tagged: operator-tag name match
Rscript R/04b_operator_class.R      # operator class for every camera (private / public_other / local / vendor ...)
Rscript R/05_method_b.R             # located: spatial assignment with per-camera b_status
Rscript R/06_combine_outputs.R      # cameras.csv, agencies.csv (tagged / located / attributed), summary_stats.csv, density plot
Rscript R/07_validate.R             # historical comparison with N&O Flock portal counts
Rscript R/07b_validate_web.R        # comparison with web-collected reported counts (data/validation_web/)
Rscript R/08_summary.R              # output/summary.md
Rscript R/09_hist_stats.R           # share of agencies by camera-count range, with mean, median, 99th percentile
Rscript R/10_checks.R               # regression checks from the 2026-10-03 audit
Rscript R/11_manifest.R             # output/run_manifest.txt: input checksums, OSM snapshot, package versions
Rscript R/09b_hist_web_sample.R      # reported vs OSM camera counts for the web-validation agencies
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

## Rerunning everything (new session / new agent)

The container is ephemeral; only what is in git survives. Start on branch `alpr-pipeline`.

**1. Environment**
- R >= 4.4 with system GDAL/GEOS/PROJ. On Ubuntu 24.04 the fastest route is r2u (binary CRAN packages via apt):
  ```
  apt-get install -y r-base-core r-cran-sf r-cran-dplyr r-cran-readr r-cran-tidyr r-cran-stringr \
    r-cran-purrr r-cran-jsonlite r-cran-httr2 r-cran-stringdist r-cran-ggplot2 r-cran-scales r-cran-digest
  ```
  (add the r2u and CRAN apt sources first; see https://github.com/eddelbuettel/r2u). Package versions used are in `output/run_manifest.txt`.
- Python 3 is only needed for ad hoc checks. `poppler-utils` (pdftotext) is handy for reading court PDFs.
- Run every script from the repo root, with `LC_ALL=C.UTF-8` (some regexes use non-ASCII characters).

**2. Inputs**

| Input | In git? | How the next run gets it |
|---|---|---|
| OSM ALPR nodes, 2026-10-03 | yes, `data/snapshots/` | `Rscript R/02b_load_osm_snapshot.R` (exact same camera table) |
| OSM, a fresh pull | no | `Rscript R/02_pull_osm.R` (~2 h; overpass-api.de may be blocked by the network, the maps.mail.ru mirror worked) |
| Census TIGER 2025 + ACS 2020-24 | no (~0.5 GB) | `R/01_download_census.R` downloads them |
| FBI CDE agency directory + `lee_1960_2025.csv` | no | `R/03_agencies.R` downloads them (signed S3 URL from cde.ucr.cjis.gov) |
| LEAIC 2012 (ICPSR 35158) | yes, `data/raw/leaic/35158-0001-Data.tsv` | committed with `git add -f`; ICPSR terms bar redistribution, so remove it from history before making the repo public |
| N&O "Private Eyes" validation file | no | `R/07_validate.R` clones the GitHub repo |
| Web-collected reported counts | yes, `data/validation_web/` | used as is by `R/07b_validate_web.R` |

Checksums of every input used in the last run are in `output/run_manifest.txt`.

**3. Run**
```
export LC_ALL=C.UTF-8
Rscript R/01_download_census.R
Rscript R/02b_load_osm_snapshot.R          # or R/02_pull_osm.R for a new snapshot
for s in 03_agencies 04_method_a 04b_operator_class 05_method_b 06_combine_outputs 07_validate \
         07b_validate_web 08_summary 09_hist_stats 09b_hist_web_sample 10_checks 11_manifest; do
  Rscript R/$s.R > output/log_$s.txt 2>&1 || { echo "FAILED: $s"; break; }
done
```
`R/10_checks.R` must report all checks passed. With the 2026-10-03 snapshot the headline numbers should
reproduce exactly (143,157 cameras; 136,080 located; 7,944 agencies with >=1 located camera).

**4. Adding more reported counts** (`data/validation_web/`)
- One CSV per region and round, named `<northeast|midwest|south|west>[_N].csv` (the validation script reads only these names), header:
  `state,agency_name,agency_type,reported_cameras,includes_mobile_or_shared,vendor,as_of_date,source_type,url,quote,notes`
- One row per agency; skip agencies already in any file. Public sources only (agency sites, government documents, news quoting officials). Never use crowdsourced maps (DeFlock / OSM / flockcameralocations) since they are what is being validated, and never leaked data.
- `transparency.flocksafety.com` (Cloudflare) and `web.archive.org` are blocked; do not try to get around them.
- Put program status (removed / paused / planned / approved) in `notes`; `R/07b_validate_web.R` flags rows from keywords there, and `status_overrides.csv` holds reviewed corrections (`program_status`: current / discontinued / planned_or_contracted / changed / not_alpr).
- Web searches are capped per session (`CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION`, default 200). Raise it in the environment settings before starting a session that will collect more. Give each parallel agent its own scratch folder.
- Still thin: AZ, UT, NV, NM, ID, MT, HI, AK, LA, DE, PA, CT, RI; several big cities (Memphis, Chicago, NYPD, Philadelphia, Pittsburgh, Omaha, Kansas City) have no published count.
- `mn_bca_fixed_lpr_locations.csv` (Minnesota BCA register of fixed LPR locations) is collected but not yet used; it lists locations, not camera counts.

**5. Open items**
- Review lists: `output/operator_classes_for_review.csv`, `method_a_fuzzy_matches_for_review.csv`, `method_b_pd_code_name_mismatches.csv`, `validation_web_unmatched.csv`.
- Not done (see `AUDIT_RESPONSE.md`): package lockfile; per-capita denominators matched to the located area.
