# alpr-per-department

Estimate the number of automated license plate readers (ALPRs) per US local police agency, by tying
crowdsourced OpenStreetMap camera data (the DeFlock layer) to law-enforcement agencies.

Status: complete run on the 2026-10-03 OSM snapshot. Results and definitions: `output/summary.md`.
Work happens on branch `alpr-pipeline`.

## Layout

| Path | Contents |
|---|---|
| `R/` | pipeline scripts `01`-`14`, `run_all.R`, shared `name_parser.R`, reviewed `operator_class_overrides.csv` |
| `data/snapshots/` | committed OSM snapshot (`osm_alpr_raw_<date>.csv.gz`) and its Overpass query log |
| `data/validation_web/` | publicly reported camera counts (one CSV per region and round), `status_overrides.csv`, Minnesota BCA register |
| `data/raw/` | downloads (not in git, except the LEAIC file) |
| `data/derived/` | cleaned and joined files |
| `output/` | results: `summary.md`, `agencies.csv`, `cameras.csv`, validation tables, plots, `run_manifest.txt` |
| `output/review/` | diagnostic lists for manual review (match candidates, operator classes, name mismatches, unmatched rows) |
| `docs/` | original task spec (`PROMPT.md`), court-case notes (`court_cases.md`); `audit/` holds the 2026-10-03 audit memo and the response |

## Data sources

- OpenStreetMap nodes tagged `man_made=surveillance` + `surveillance:type=ALPR` (Overpass API)
- FBI Crime Data Explorer agency directory and law enforcement employee file (population served)
- BJS Law Enforcement Agency Identifiers Crosswalk (LEAIC) 2012
- Census TIGER/Line 2025 boundaries and ACS 2020-24 population
- Validation: The News & Observer "Private Eyes" Flock portal data (https://github.com/mcclatchy-southeast/private_eyes);
  web-collected reported counts (`data/validation_web/`); Minnesota BCA register of fixed LPR locations

## Known limits

- 84% of OSM cameras have no operator tag; untagged cameras of other operators (HOAs, businesses,
  sheriffs, state agencies) inside an agency's area are counted for that agency.
- Volunteer mapping coverage is uneven. Car-mounted readers are not in OSM.
- LEAIC is old; newer agencies are matched by name.
- Nothing here measures what an agency can search through shared networks.

## Scripts

| Script | Does |
|---|---|
| `01_download_census.R` | TIGER/Line 2025 states, counties, places, county subdivisions; ACS 2020-24 B01003 |
| `02_load_osm_snapshot.R [date]` | camera table from the committed snapshot (default) |
| `02_pull_osm.R` | alternative: new Overpass pull, state by state (~2 h) |
| `03_agencies.R` | FBI directory + employee file + LEAIC; `record_status`, county fallback |
| `04_method_a.R` | **tagged**: operator tag matched to an agency name |
| `05_operator_class.R` | operator class per camera (private / public_other / local / vendor ...) |
| `06_method_b.R` | **located**: spatial assignment, per-camera `b_status` |
| `07_combine_outputs.R` | `cameras.csv`, `agencies.csv` (tagged / located / attributed), `summary_stats.csv` |
| `08_validate_portal.R` | historical comparison with N&O Flock portal counts |
| `09_validate_web.R` | comparison with web-collected reported counts; Minnesota BCA register check |
| `10_hist_stats.R` | share of agencies by camera-count range |
| `11_hist_web_sample.R` | reported vs OSM counts for the web-validation agencies |
| `12_summary.R` | `output/summary.md` |
| `13_checks.R` | regression checks from the 2026-10-03 audit (must all pass) |
| `14_manifest.R` | `output/run_manifest.txt`: input checksums, OSM snapshot, package versions, git commit |

## Rerunning everything

The container is ephemeral; only what is in git survives. Start on branch `alpr-pipeline`.

**1. Environment.** R >= 4.4 with system GDAL/GEOS/PROJ. On Ubuntu 24.04 use r2u (binary CRAN packages via apt;
add the r2u and CRAN apt sources first, see https://github.com/eddelbuettel/r2u):
```
apt-get install -y r-base-core r-cran-sf r-cran-dplyr r-cran-readr r-cran-tidyr r-cran-stringr \
  r-cran-purrr r-cran-jsonlite r-cran-httr2 r-cran-stringdist r-cran-ggplot2 r-cran-scales r-cran-digest
```
Package versions used are in `output/run_manifest.txt`.

**2. Inputs.**

| Input | In git? | How a run gets it |
|---|---|---|
| OSM ALPR nodes, 2026-10-03 | yes, `data/snapshots/` | `02_load_osm_snapshot.R` |
| Census TIGER 2025 + ACS 2020-24 | no (~0.5 GB) | `01_download_census.R` |
| FBI CDE directory + `lee_1960_2025.csv` | no | `03_agencies.R` (signed S3 URL from cde.ucr.cjis.gov) |
| LEAIC 2012 (ICPSR 35158) | yes, `data/raw/leaic/35158-0001-Data.tsv` | committed with `git add -f`. ICPSR terms bar redistribution: remove it from history before making the repo public. Manual download: https://www.icpsr.umich.edu/web/NACJD/studies/35158 -> DS1, delimited |
| N&O "Private Eyes" file | no | `08_validate_portal.R` clones the repo (file dated 2024-04-26 despite "2023" in its name) |
| Web-collected counts, MN register | yes, `data/validation_web/` | used as is |

**3. Run** (from the repo root):
```
export LC_ALL=C.UTF-8     # some regexes use non-ASCII characters
Rscript R/run_all.R       # or --pull for a new OSM snapshot; --from 03 to skip downloads
```
Logs go to `output/log_<script>.txt`. With the 2026-10-03 snapshot the headline numbers reproduce exactly
(143,157 cameras; 135,907 located; 7,941 agencies with >=1 located camera; asserted by `13_checks.R`); last confirmed by a full rebuild on 2026-10-03.

Access notes: Overpass tries `overpass-api.de`, then the `maps.mail.ru` mirror (endpoint and timestamp per state in
the query log). The Census API now needs a key, so ACS comes from the summary-file download.

## Adding reported counts (`data/validation_web/`)

- One CSV per region and round, named `<northeast|midwest|south|west>[_N].csv` (only these names are read), header:
  `state,agency_name,agency_type,reported_cameras,includes_mobile_or_shared,vendor,as_of_date,source_type,url,quote,notes`
- One row per agency; skip agencies already in any file. Every row needs a URL and an exact quote checked against the page.
  Public sources only (agency sites, government documents, news quoting officials). Never crowdsourced maps
  (DeFlock / OSM / flockcameralocations / Atlas of Surveillance), which are what is being validated, and never leaked data. AI-generated meeting summaries (citizenportal.ai) are not sources. A news report that relays a figure from an agency's Flock transparency portal is accepted; say so in `notes` (about 30 rows).
- `transparency.flocksafety.com` (Cloudflare) and `web.archive.org` are blocked; do not try to get around them.
- Put program status (removed / paused / planned / approved) in `notes`. `09_validate_web.R` flags rows from keywords there;
  `status_overrides.csv` holds reviewed corrections (`current` / `discontinued` / `planned_or_contracted` / `changed` / `locations_not_cameras` / `not_alpr`); only `current` rows with `includes_mobile_or_shared = no` enter the core comparison.
  Name aliases (source name -> FBI name) are in `ALIAS` in `09_validate_web.R`; unmatched rows go to `output/review/validation_web_unmatched.csv`.
- Web searches are capped per session (`CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION`). Give each parallel agent its own scratch folder.
- Still thin (0-3 rows, after round 3): AK and MT (0; Anchorage uses only car-mounted readers, Montana law limits police
  ALPRs on public roads), DC, VT, WY (1), NH (2), HI, ND, SD (3). LA has 6 after the 2026-10-03 review removed 8 rows sourced from an Atlas of Surveillance list. Big cities with no published count of police-operated
  fixed readers: Chicago (only a 2022 figure mixing fixed and car-mounted), Omaha, Kansas City KS, Minneapolis
  (only "30 intersections"), Cincinnati (pilot, no contract), Pittsburgh, San Antonio (car-mounted only). NYPD has only a
  2016 figure ("some 500", fixed and mobile not separated); Memphis's 200 includes private cameras shared with MPD.
- `mn_bca_fixed_lpr_locations.csv` (Minnesota BCA register, checked against the live BCA page on 2026-10-03) is compared
  separately (summary section 5c). It lists locations, not cameras.

## Open items

- Review lists in `output/review/`.
- Not done (see `docs/audit/AUDIT_RESPONSE.md`): package lockfile; per-capita denominators matched to the located area.
