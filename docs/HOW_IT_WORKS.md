# How the code works

This repo answers one question: how many automated license plate readers (ALPRs) does each US local police
agency have? It answers it by taking cameras that volunteers have mapped in OpenStreetMap, crediting each one to
a police department or sheriff's office, and then checking the result against counts that agencies have
published. A separate spreadsheet compares how often drivers were photographed in court cases.

Everything runs with one command from the repo root:

```
Rscript R/run_all.R
```

`run_all.R` runs nine scripts in order. Each script reads the files the earlier ones wrote and writes its own.
Intermediate files go to `data/derived/` (not in git); results go to `output/`. Each script's log, with row
counts after every join and filter, goes to `output/log_<script>.txt`.

## The steps

### 1. Census boundaries: `R/01_census.R`

Downloads the Census Bureau's 2025 boundary files (states, counties, cities and towns, and county subdivisions
such as New England towns and Midwest townships) and the 2020-24 population estimates, and joins population onto
each area. These maps are what the later steps use to decide which agency's territory a camera is in.

*Output:* `data/derived/{states,counties,places,cousubs}.rds`. *First run only:* about 0.5 GB of downloads.

### 2. Camera data: `R/02_osm_snapshot.R`

Loads the committed OpenStreetMap snapshot, `data/snapshots/osm_alpr_raw_2026-10-03.csv.gz`: every point
tagged `man_made=surveillance` and `surveillance:type=ALPR` in the 50 states and DC, 143,157 in all. Each row
has the camera's location and its tags: manufacturer, operator, direction and so on.

The snapshot was made by `R/osm_pull.R`, which queries the live OpenStreetMap database state by state. It isn't
part of a normal run because it takes about two hours and would give slightly different numbers each time; run
`Rscript R/run_all.R --pull` to make a new snapshot.

*Output:* `data/derived/osm_alpr.rds`.

### 3. Agency list: `R/03_agencies.R`

Builds the list of local law-enforcement agencies from three sources:

- **FBI agency directory**: every agency's ID code (its "ORI"), name, type and county.
- **FBI employee file**: the population each agency serves, and whether it reports any staff.
- **Bureau of Justice Statistics crosswalk (LEAIC, 2012)**: links each ORI to a Census city or county code.

The FBI files are pinned in `data/snapshots/` so reruns give the same answer. The script keeps city police,
sheriffs and county police, and marks each record's status:

- **current**: receives cameras.
- **contract_city**: a city the FBI lists as a "Police Department" that actually pays the sheriff for policing
  (detected as no staff on record, in California or with an ORI ending in "X"). It gets no cameras; its
  cameras go to whoever polices it.
- **historical**: an old record of an agency that no longer exists.

It also drops three crosswalk codes that now belong to a different agency, and fills in missing county codes from
the FBI directory.

*Output:* `data/derived/agencies.rds` (14,762 current agencies).

### 4. Match operator tags to agencies: `R/04_match_operator_names.R`

About 16% of cameras have an operator tag, such as "Austin Police Department" or "City of Hollywood". This step
matches each tag to an agency in the same state. Names are normalized first (`R/name_parser.R`: lowercase,
accents removed, "PD" and "Sheriff's Office" stripped down to the place name), then matched exactly, then with
small variations (dropping "city"/"town", adding "county"), and finally by close spelling, accepted only when one
candidate is clearly best. Matches never cross state lines.

*Output:* `data/derived/operator_match.rds`; review list `output/review/operator_crosswalk.csv`.

### 5. Classify operators: `R/05_classify_operators.R`

Puts every camera's operator in one class, using the match from step 4 and keyword rules:

| Class | Meaning | Counted? |
|---|---|---|
| `local_police` / `local_government` | names a local agency (matched in step 4) | yes, for that agency |
| `missing` | no operator tag (84% of cameras) | yes, by location |
| `vendor` | names the maker, e.g. "Flock Safety" | yes, by location |
| `police_unmatched`, `unclassified` | police-like or unclear names with no match | yes, by location |
| `private` | businesses, HOAs, stores, hospitals, or tagged private | **no** |
| `public_other` | state police, DOTs, transit, universities, federal agencies | **no** |

`data/operator_class_overrides.csv` holds hand-reviewed exceptions that override the rules.

*Output:* `data/derived/operator_class.rds`.

### 6. Credit each camera to an agency: `R/06_locate_cameras.R`

The core step. First it finds which city, county subdivision and county each camera sits in. Then it works out
each agency's territory:

- **City and town police**: the crosswalk code for their city. Corrections: departments with no usable code are
  matched to a city by exact name (same county only); Wisconsin village departments wrongly coded to the
  neighboring town are moved to the village; three contract cities are given to the neighboring department
  that actually serves them (Monte Sereno to Los Gatos, for example).
- **Sheriffs and county police**: their county, outside the cities that have their own department.
- **Countywide departments**: where one city department serves at least half a county's people (consolidated
  city-counties), it covers the parts of the county no one else does.

Each camera is then credited by these rules, in order:

1. Excluded if its operator is private or another public body (step 5), or if it's tagged destroyed or disabled.
2. If its operator tag names a local agency, credited to that agency, wherever the camera is.
3. Otherwise, credited to the city or town department whose territory contains it.
4. Otherwise (unincorporated area, or a city with no department of its own), credited to the county agency.

The column `located_status` records which rule placed each camera, so any count can be traced.

*Output:* `data/derived/camera_location.rds`, `agency_area.rds`; review lists in `output/review/located_*.csv`.

### 7. Count per agency: `R/07_count_per_agency.R`

Joins everything into one table per camera and one per agency. A map point tagged as holding several cameras
(`camera:count`) counts each one. Agencies with no cameras are kept, with `area_resolved` saying whether a zero is
a real mapped zero or an agency whose territory couldn't be placed on the map.

*Output:* `output/csv/cameras.csv.gz` (written by a run, not in git), `agencies.csv`, `summary_stats.csv`.
Headline: 135,872 cameras credited to 7,795 agencies; the median agency with at least one camera has 6.

### 8. Validate against published counts: `R/08_validate.R`

Reads the publicly reported counts in `data/validation_web/` (699 rows, each with a source link and an exact
quote), classifies each program as current, discontinued or planned (keyword rules plus reviewed overrides in
`status_overrides.csv`), and matches each row to the agency list with the same name parser.

The **core comparison** keeps the 360 agencies with a current program and a count of fixed cameras the agency
operates. Where the agency's figure is a count of Flock cameras, only Flock-tagged map points are counted. It
then computes how close the mapped and reported counts are: correlation on a log scale, share within a factor of
two, share within 20%, median ratio, and the same split by agency size and source date. Minnesota's state
register of reader locations is compared separately.

*Output:* `output/csv/validation_web_comparison.csv` (one row per agency), `reported_cameras_by_department.csv`
(the same list with sources), `validation_web_metrics.csv`. Headline: 75% within a factor of two, 40% within
20%, correlation 0.83.

### 9. Charts: `R/09_charts.R`

Draws the four charts from files that are all in git, so `Rscript R/09_charts.R` works on its own:

- `validation_web_scatter.png`: reported vs. mapped cameras for the 360 agencies.
- `hist_cameras_per_agency_stats.png`: all agencies with at least one mapped camera, by number of cameras
  (median 6).
- `hist_reported_cameras_per_agency.png`: the validation agencies, by the number of cameras they reported
  (median 17). They are larger than the typical agency, so this is not an estimate for all agencies.
- `court_observations_per_day.png`: captures per day in ALPR court rulings vs. *Carpenter*, from the
  hand-built spreadsheet `docs/alpr_observation_counts.xlsx`.

The chart style (fonts, colors, size, transparent background) is in `R/theme_cf.R`.

## Where to look when a number seems wrong

| Question | Look at |
|---|---|
| Why does agency X have N cameras? | `output/csv/cameras.csv.gz`: filter `located_ori` to the agency; `located_status` says why each camera is there |
| Why was a camera left out? | its `op_class` and `located_status` in `cameras.csv.gz` |
| What territory does an agency cover? | `area` in `output/csv/agencies.csv` |
| Was an operator tag matched correctly? | `output/review/operator_crosswalk.csv` |
| Why is a validation agency compared the way it is? | `output/csv/validation_web_comparison.csv` (`core`, `flock_only`, `program_status`) |
| Where did a court count come from? | `docs/alpr_observation_counts.xlsx`, pin cite and URL columns |

## What the counts are not

- Not an inventory of cameras an agency owns: untagged cameras of other operators inside an agency's
  territory count for it.
- Not complete: volunteer mapping is uneven, and car-mounted readers aren't mapped.
- Not a measure of what an agency can search: shared networks give access far beyond its own cameras.
