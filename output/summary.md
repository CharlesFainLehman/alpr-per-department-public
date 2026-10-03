# ALPRs per US police agency: summary

OSM pull: 2026-10-03 (Overpass; OSM base timestamps 2026-10-03 13:08:13 to 2026-10-03 15:24:51). Agencies: FBI CDE directory + FBI employee file (population served, latest year per ORI) + BJS LEAIC 2012. Boundaries: TIGER/Line 2025. Population: ACS 2020-2024 5-year.

## 1. Camera data

- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), inside the 50 states + DC: **143,157**
- With a non-empty `operator` tag: **23,450 (16.4%)**
- By manufacturer (spelling variants grouped; full list in `osm_counts_by_manufacturer.csv`):

| manufacturer | cameras | share |
| --- | --- | --- |
| Flock | 111,315 | 77.8% |
| Motorola / Vigilant |   7,374 | 5.2% |
| Genetec |   3,465 | 2.4% |
| Axis |   2,981 | 2.1% |
| Leonardo / ELSAG |   1,242 | 0.9% |
| Rekor |     824 | 0.6% |
| Axon |     755 | 0.5% |
| PlateSmart |     746 | 0.5% |
| (no manufacturer tag) |  11,102 | 7.8% |

## 2. Agency list

- 15,126 local agencies: 12,093 municipal police, 2,985 sheriffs, 46 county police, 2 county agencies of unclear type.
- 202 agencies have no LEAIC record (ORI created or changed after 2012). 761 have no FBI population.

## 3. Crosswalk

### Method A: operator tag

| a_basis | n |
| --- | --- |
| (no operator tag, or unmatched) | 129,607 |
| exact |  12,038 |
| jurisdiction_only |   1,020 |
| exact_no_muni_word |     383 |
| exact_county_added |      82 |
| fuzzy |      27 |

- Fuzzy: 64 candidates written to `method_a_fuzzy_matches_for_review.csv`; 10 accepted (all spelling typos). Never across states.
- `jurisdiction_only` = operator names a city or county without an agency word ("City of Beverly Hills"); assigned to that jurisdiction's PD or sheriff. Review these.

### Method B: spatial join

| b_level | n |
| --- | --- |
| place | 96,562 |
| county | 30,803 |
| county_subdivision |  6,376 |
| excluded_private |  4,110 |
| place_without_pd_to_county |  4,030 |
| countywide_pd_no_county_agency |    641 |
| consolidated_countywide_pd |    433 |
| unassigned |    202 |

- Excluded as private: **4,110 cameras** (surveillance=private: 177; operator:type private/business/university etc.: 1,920; operator name looks private (retailer, mall, HOA, school, hospital...): 3,870). Overlapping flags counted once in the total.
- `place_without_pd_to_county` (4,030 cameras): inside a city with no PD in the agency list (mostly contract cities); assigned to the sheriff.
- `county_subdivision`: town/township police in New England, NJ, PA, MI, NY, OH etc. (towns that are not Census places). Not in the original spec; without it these cameras would go to the sheriff.
- County-wide municipal PDs (1,074 cameras): Louisville Metro, Athens-Clarke (consolidated governments), Charlotte-Mecklenburg, Las Vegas Metro, Metro Nashville, Honolulu, Los Alamos, Indianapolis (counties with no sheriff/county-police record).
- 160 PDs had no usable LEAIC place code and were linked to a 2025 Census place by exact unique name (`method_b_pd_place_name_matches.csv`).
- `unassigned`: areas policed by state police (DE, PA, CT, MA, RI, VT). Correctly not assigned to a local agency.

### A vs. B

| a_b_compare | n |
| --- | --- |
| B only | 125,335 |
| agree |  12,363 |
| neither |   4,272 |
| disagree |   1,147 |
| A only |      40 |

Disagreements are mostly county agencies operating cameras inside city limits (e.g., St. Charles County PD inside St. Charles and O'Fallon, MO) and cities placing cameras just past their borders. Method B gives those to the city.

## 4. Cameras per agency

### Method B (spatial join; the main estimate)

Overall and by agency type:

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  8,000 | 138,845 | 17.4 | 6.0 | 1 | 2.0 | 16.0 | 37.0 | 177.0 | 2,443 |
| all agencies | all | 15,126 | 138,845 | 9.2 | 1.0 | 0 | 0.0 | 7.0 | 21.0 | 121.0 | 2,443 |
| agencies with >=1 camera | Municipal police |  5,998 | 104,012 | 17.3 | 6.0 | 1 | 2.0 | 16.0 | 37.0 | 160.2 | 2,443 |
| agencies with >=1 camera | Sheriff |  1,963 |  30,508 | 15.5 | 6.0 | 1 | 3.0 | 15.0 | 31.0 | 163.3 | 1,111 |
| agencies with >=1 camera | County police |     39 |   4,325 | 110.9 | 57.0 | 8 | 16.5 | 139.0 | 233.6 | 620.2 |   711 |
| all agencies | Municipal police | 12,093 | 104,012 | 8.6 | 0.0 | 0 | 0.0 | 6.0 | 20.0 | 108.1 | 2,443 |
| all agencies | Sheriff |  2,985 |  30,508 | 10.2 | 3.0 | 0 | 0.0 | 9.0 | 22.0 | 136.0 | 1,111 |
| all agencies | County police |     46 |   4,325 | 94.0 | 46.5 | 0 | 8.2 | 131.2 | 218.5 | 603.4 |   711 |
| all agencies | County (type unclear) |      2 |       0 | 0.0 | 0.0 | 0 | 0.0 | 0.0 | 0.0 | 0.0 |     0 |

By population served (FBI):

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | <2.5k |   962 |  3,269 | 3.4 |   2 | 1.0 | 1.0 | 4.0 | 6.0 | 21.0 |   189 |
| agencies with >=1 camera | 2.5k-10k | 2,176 | 11,040 | 5.1 |   4 | 1.0 | 2.0 | 6.0 | 11.0 | 27.2 |    59 |
| agencies with >=1 camera | 10k-25k | 2,073 | 19,682 | 9.5 |   7 | 1.0 | 3.0 | 13.0 | 20.0 | 46.0 |    71 |
| agencies with >=1 camera | 25k-50k | 1,236 | 20,699 | 16.7 |  13 | 3.0 | 6.0 | 22.0 | 35.0 | 71.7 |   184 |
| agencies with >=1 camera | 50k-100k |   720 | 21,031 | 29.2 |  23 | 5.0 | 11.0 | 39.2 | 59.0 | 132.2 |   221 |
| agencies with >=1 camera | 100k-250k |   377 | 23,782 | 63.1 |  52 | 12.6 | 28.0 | 86.0 | 126.4 | 206.6 |   289 |
| agencies with >=1 camera | 250k+ |   151 | 34,006 | 225.2 | 143 | 47.0 | 81.5 | 247.0 | 475.0 | 1,315.0 | 2,443 |
| agencies with >=1 camera | unknown |   305 |  5,336 | 17.5 |   6 | 1.0 | 2.0 | 21.0 | 48.6 | 128.3 |   225 |
| all agencies | <2.5k | 4,269 |  3,269 | 0.8 |   0 | 0.0 | 0.0 | 0.0 | 2.0 | 10.0 |   189 |
| all agencies | 2.5k-10k | 4,635 | 11,040 | 2.4 |   0 | 0.0 | 0.0 | 3.0 | 7.0 | 20.7 |    59 |
| all agencies | 10k-25k | 2,790 | 19,682 | 7.1 |   4 | 0.0 | 0.0 | 10.0 | 18.0 | 42.1 |    71 |
| all agencies | 25k-50k | 1,390 | 20,699 | 14.9 |  11 | 0.0 | 4.0 | 20.8 | 34.0 | 70.1 |   184 |
| all agencies | 50k-100k |   747 | 21,031 | 28.2 |  22 | 3.0 | 9.0 | 38.0 | 58.0 | 131.2 |   221 |
| all agencies | 100k-250k |   381 | 23,782 | 62.4 |  52 | 11.0 | 27.0 | 86.0 | 126.0 | 206.2 |   289 |
| all agencies | 250k+ |   153 | 34,006 | 222.3 | 143 | 46.0 | 80.0 | 242.0 | 474.4 | 1,314.7 | 2,443 |
| all agencies | unknown |   761 |  5,336 | 7.0 |   0 | 0.0 | 0.0 | 4.0 | 21.0 | 88.8 |   225 |

### Method A (operator tag; a floor, not an estimate)

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  1,064 | 13,550 | 12.7 | 5 | 1 | 2 | 12.0 | 25.0 | 125.4 | 591 |
| all agencies | all | 15,126 | 13,550 | 0.9 | 0 | 0 | 0 | 0.0 | 0.0 | 19.0 | 591 |
| agencies with >=1 camera | Municipal police |    885 | 11,853 | 13.4 | 5 | 1 | 2 | 12.0 | 26.6 | 138.3 | 591 |
| agencies with >=1 camera | Sheriff |    163 |  1,338 | 8.2 | 3 | 1 | 1 | 9.0 | 16.8 | 81.6 |  91 |
| agencies with >=1 camera | County police |     16 |    359 | 22.4 | 4 | 2 | 2 | 15.2 | 58.0 | 163.3 | 175 |
| all agencies | Municipal police | 12,093 | 11,853 | 1.0 | 0 | 0 | 0 | 0.0 | 0.0 | 22.0 | 591 |
| all agencies | Sheriff |  2,985 |  1,338 | 0.4 | 0 | 0 | 0 | 0.0 | 0.0 | 12.0 |  91 |
| all agencies | County police |     46 |    359 | 7.8 | 0 | 0 | 0 | 2.0 | 12.0 | 139.9 | 175 |
| all agencies | County (type unclear) |      2 |      0 | 0.0 | 0 | 0 | 0 | 0.0 | 0.0 | 0.0 |   0 |

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | <2.5k |    39 |   124 | 3.2 |  2 | 1.0 | 1.5 | 4.0 | 6.4 | 8.0 |   8 |
| agencies with >=1 camera | 2.5k-10k |   158 |   753 | 4.8 |  3 | 1.0 | 2.0 | 6.0 | 9.3 | 28.0 |  30 |
| agencies with >=1 camera | 10k-25k |   258 | 1,717 | 6.7 |  4 | 1.0 | 2.0 | 7.8 | 15.0 | 41.6 |  91 |
| agencies with >=1 camera | 25k-50k |   246 | 2,220 | 9.0 |  6 | 1.0 | 2.0 | 13.0 | 20.0 | 47.0 |  78 |
| agencies with >=1 camera | 50k-100k |   163 | 1,987 | 12.2 |  7 | 1.0 | 2.0 | 15.5 | 32.6 | 61.1 |  72 |
| agencies with >=1 camera | 100k-250k |   117 | 2,670 | 22.8 | 10 | 1.0 | 3.0 | 32.0 | 68.6 | 160.8 | 175 |
| agencies with >=1 camera | 250k+ |    69 | 4,046 | 58.6 | 19 | 1.8 | 4.0 | 63.0 | 143.6 | 495.1 | 591 |
| agencies with >=1 camera | unknown |    14 |    33 | 2.4 |  1 | 1.0 | 1.0 | 1.0 | 5.5 | 12.2 |  13 |
| all agencies | <2.5k | 4,269 |   124 | 0.0 |  0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |   8 |
| all agencies | 2.5k-10k | 4,635 |   753 | 0.2 |  0 | 0.0 | 0.0 | 0.0 | 0.0 | 5.0 |  30 |
| all agencies | 10k-25k | 2,790 | 1,717 | 0.6 |  0 | 0.0 | 0.0 | 0.0 | 0.0 | 14.0 |  91 |
| all agencies | 25k-50k | 1,390 | 2,220 | 1.6 |  0 | 0.0 | 0.0 | 0.0 | 5.0 | 24.1 |  78 |
| all agencies | 50k-100k |   747 | 1,987 | 2.7 |  0 | 0.0 | 0.0 | 0.0 | 8.0 | 47.1 |  72 |
| all agencies | 100k-250k |   381 | 2,670 | 7.0 |  0 | 0.0 | 0.0 | 2.0 | 22.0 | 105.2 | 175 |
| all agencies | 250k+ |   153 | 4,046 | 26.4 |  0 | 0.0 | 0.0 | 12.0 | 76.8 | 386.6 | 591 |
| all agencies | unknown |   761 |    33 | 0.0 |  0 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 |  13 |

Cameras per 10,000 residents are in `agencies.csv` (`per10k_a`, `per10k_b`), using FBI population served. A sheriff's FBI population is usually only the unincorporated area, so method B counts for sheriffs are per that area.

## 5. Validation (N&O "Private Eyes", Flock transparency portals, 2024-04-26)

- 336 rows after dropping Flock/Training/DNU rows and rows with no camera count; 314 matched to the agency list (unmatched are mostly universities, airports, DAs, tribal PDs).
- Compared with OSM **Flock-manufacturer** cameras assigned to the agency.

| method | n | pearson_r | spearman_rho | pearson_r_log1p | median_ratio | median_abs_error | share_osm_zero | share_osm_above_reported |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 314 | 0.19 | 0.33 | 0.34 | 0.00 | 9.50 | 0.63 | 0.08 |
| B | 314 | 0.63 | 0.78 | 0.75 | 1.21 | 6.00 | 0.05 | 0.61 |

- Method A among the 116 agencies where it finds at least one camera: median ratio 0.60, r(log) 0.33.
- OSM data are 2.5 years newer than the portal counts, so OSM counts above the 2024 figure are expected (method B: median ratio above 1). Method B also counts Flock cameras owned by other public bodies inside the city (e.g., county agencies, DOTs), which pushes it up; method A misses every untagged camera, which pushes it to zero for most agencies.
- Plot: `validation_scatter.png`.

## 6. Limits of the data

- **Untagged operators.** Only 16.4% of cameras have an operator tag, so method A is a floor. Method B infers the owner from location.
- **Private cameras inside city limits.** Method B excludes only cameras tagged private or with an obviously private operator name. Untagged private cameras (HOAs, businesses, which Flock sells to heavily) are assigned to the local PD. Flock as `operator` (a vendor, not an owner) is not excluded.
- **Overlapping jurisdictions.** Cameras run by sheriffs, county police, state police, DOTs, transit and university police inside a city are assigned to the city PD by method B. Where >1 PD or >1 county agency shares a code, the one with the largest FBI population gets the cameras (`method_b_places_with_multiple_pds.csv`, `method_b_counties_with_multiple_county_agencies.csv`).
- **Uneven volunteer coverage.** DeFlock/OSM mapping is crowdsourced. Zero cameras means none mapped, not none installed. Coverage is denser where active mappers live; cross-agency comparisons reflect mapping effort as well as deployment.
- **Age of LEAIC.** LEAIC is from 2012. 202 agencies have no LEAIC record; place codes for consolidated governments changed since (handled by the county-wide rule); new cities and new PDs are matched by name (160) or fall to the sheriff.
- **Population served.** FBI figures (latest year 2020-2025). Missing for some agencies; per-capita values are NA there. Sheriffs with zero FBI population (no patrol area) have NA per-capita rates.
- **Contract cities.** California contract cities (ORIs ending in X, e.g., Mission Viejo PD) are separate FBI agencies served by the sheriff; method B gives them their own cameras.
- **Mobile ALPRs** (car-mounted) are not in OSM; these counts are fixed cameras only.
- No leaked or non-public Flock data were used.
