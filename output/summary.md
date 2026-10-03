# Mapped ALPRs per US local police agency: summary

OSM pull 2026-10-03 (Overpass; OSM base timestamps 2026-10-03 13:08:13 to 2026-10-03 15:24:51). Agencies: FBI CDE directory + FBI employee file (population served) + BJS LEAIC 2012. Boundaries: TIGER/Line 2025. Population: ACS 2020-2024 5-year.

**What these numbers are.** Counts of license plate reader cameras *mapped* in OpenStreetMap (the crowdsourced layer DeFlock maintains), tied to local agencies three ways. None is a verified inventory of cameras an agency owns, and none measures what an agency can *search*: through shared networks (e.g., Flock sharing and national lookup) an agency can query cameras far outside its own area. Neither the tagged nor the located measure is a lower or upper bound: both omit some cameras and include some wrongly.

| Measure | Definition |
| --- | --- |
| **Located** | Cameras inside the agency's area (incorporated place, town/township, or the county outside them), excluding cameras whose operator tag names a private party or another public body (DOT, transit, state police, federal, university, school). Includes cameras with no operator tag. |
| **Tagged** | Cameras whose `operator` tag names the agency (name match within the state). |
| **Attributed** | Tagged cameras, plus cameras with no operator, a vendor-only tag ("Flock Safety"), or an unmatched police tag that are located in the agency's area (inferred). |

Changes since the first version follow the 2026-10-03 audit; see `AUDIT_RESPONSE.md`.

## 1. Camera data

- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), 50 states + DC: **143,157**. 2,391 rows share exact coordinates with another node (possible duplicates or multi-direction installs; flagged `n_same_coords`, not removed).
- With an `operator` tag: **23,547 (16.4%)**.
- By manufacturer (spelling variants grouped; full list `osm_counts_by_manufacturer.csv`):

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

- Operator class (rules in `R/04b_operator_class.R`; every string and its class in `operator_classes_for_review.csv`):

| operator_class | cameras | share |
| --- | --- | --- |
| missing | 119,610 | 83.6% |
| local_police |  12,549 | 8.8% |
| private |   4,324 | 3.0% |
| public_other |   2,560 | 1.8% |
| vendor |   2,165 | 1.5% |
| local_government |   1,028 | 0.7% |
| unclassified |     523 | 0.4% |
| police_unmatched |     398 | 0.3% |

## 2. Agency list

- 15,126 local agencies in the table: 12,089 municipal police, 2,989 sheriffs, 46 county police, 2 unclear.
- 212 are **historical** records (not in the current FBI directory; last employee report before 2024). They stay in `agencies.csv`, flagged, but get no cameras and are excluded from the statistics below. 14,914 current agencies remain.
- Geography: 14,748 current agencies have a usable place or county code; 166 do not (`geo_status`).

## 3. How cameras were placed (located measure)

| b_status | cameras |
| --- | --- |
| direct_place | 93,414 |
| county_unincorporated | 30,394 |
| direct_cousub |  6,166 |
| excluded_private |  4,324 |
| inferred_no_pd_in_place |  4,168 |
| excluded_public_other |  2,560 |
| inferred_countywide_pd |  1,076 |
| direct_place_name_mismatch |    798 |
| no_local_agency |    192 |
| direct_cousub_name_mismatch |     64 |
| unresolved_shared_code |      1 |

- `direct_*_name_mismatch`: the PD's LEAIC code points to a Census entity with a different name. Mostly spelling (Middleboro/Middleborough) or consolidated governments (Metro Nashville, Lexington-Fayette); listed in `method_b_pd_code_name_mismatches.csv` for review.
- `inferred_*`: assignment by rule, not verified (city with no PD in the list -> county agency; consolidated government or county with no county agency -> county-wide PD).
- `unresolved_shared_code`: two PDs share a code and the name does not decide it; left unassigned.
- `no_local_agency`: state-police areas (DE, PA, New England); correctly not assigned.

Attribution basis:

| attr_basis | cameras |
| --- | --- |
| inferred_location_missing | 119,442 |
| tagged |  13,577 |
| (not attributed) |   7,065 |
| inferred_location_vendor |   2,165 |
| inferred_location_unclassified |     523 |
| inferred_location_police_unmatched |     385 |

Agencies with zero located cameras, by reason:

| reason | agencies |
| --- | --- |
| no mapped cameras in area | 6,798 |
| historical record (not assigned) |   212 |
| no usable geography: no_usable_place_code |   131 |
| no usable geography: county_shared_other_agency_assigned |    26 |
| no usable geography: place_code_shared_not_assigned |     9 |
| no usable geography: countywide_only |     6 |

## 4. Cameras per agency

### Located (current agencies)

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  7,944 | 136,080 | 17.1 | 6.0 | 1 | 2.0 | 16.0 | 37.0 | 174.3 | 2,442 |
| agencies with >=1 camera | Municipal police |  5,942 | 101,518 | 17.1 | 6.0 | 1 | 2.0 | 16.0 | 37.0 | 157.2 | 2,442 |
| agencies with >=1 camera | Sheriff |  1,961 |  30,139 | 15.4 | 6.0 | 1 | 3.0 | 15.0 | 31.0 | 163.8 | 1,101 |
| agencies with >=1 camera | County police |     41 |   4,423 | 107.9 | 60.0 | 8 | 19.0 | 138.0 | 221.0 | 615.4 |   711 |
| agencies with usable geography | all | 14,748 | 136,080 | 9.2 | 1.0 | 0 | 0.0 | 7.0 | 21.0 | 121.5 | 2,442 |
| agencies with usable geography | Municipal police | 11,743 | 101,518 | 8.6 | 1.0 | 0 | 0.0 | 6.0 | 20.0 | 109.6 | 2,442 |
| agencies with usable geography | Sheriff |  2,962 |  30,139 | 10.2 | 3.0 | 0 | 0.0 | 9.0 | 22.0 | 135.4 | 1,101 |
| agencies with usable geography | County police |     42 |   4,423 | 105.3 | 58.5 | 8 | 15.2 | 136.2 | 219.2 | 613.0 |   711 |
| agencies with usable geography | County (type unclear) |      1 |       0 | 0.0 | 0.0 | 0 | 0.0 | 0.0 | 0.0 | 0.0 |     0 |

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | <2.5k |   938 |  3,119 | 3.3 | 2.0 | 1.0 | 1.0 |   4 | 6.0 | 20.0 |   189 |
| agencies with >=1 camera | 2.5k-10k | 2,157 | 10,943 | 5.1 | 4.0 | 1.0 | 2.0 |   6 | 11.0 | 27.4 |    59 |
| agencies with >=1 camera | 10k-25k | 2,063 | 19,498 | 9.5 | 7.0 | 1.0 | 3.0 |  13 | 20.0 | 45.4 |    71 |
| agencies with >=1 camera | 25k-50k | 1,232 | 20,543 | 16.7 | 13.0 | 3.0 | 6.0 |  22 | 35.0 | 71.7 |   184 |
| agencies with >=1 camera | 50k-100k |   718 | 20,748 | 28.9 | 22.0 | 5.0 | 11.0 |  38 | 58.0 | 132.3 |   221 |
| agencies with >=1 camera | 100k-250k |   380 | 23,636 | 62.2 | 52.0 | 12.0 | 27.0 |  86 | 124.0 | 206.3 |   289 |
| agencies with >=1 camera | 250k+ |   151 | 32,299 | 213.9 | 143.0 | 47.0 | 81.5 | 231 | 467.0 | 1,178.0 | 2,442 |
| agencies with >=1 camera | unknown |   305 |  5,294 | 17.4 | 6.0 | 1.0 | 2.0 |  21 | 48.0 | 128.3 |   225 |
| agencies with usable geography | <2.5k | 4,063 |  3,119 | 0.8 | 0.0 | 0.0 | 0.0 |   0 | 2.0 | 9.4 |   189 |
| agencies with usable geography | 2.5k-10k | 4,549 | 10,943 | 2.4 | 0.0 | 0.0 | 0.0 |   3 | 7.0 | 20.5 |    59 |
| agencies with usable geography | 10k-25k | 2,747 | 19,498 | 7.1 | 4.0 | 0.0 | 1.0 |  10 | 18.0 | 41.1 |    71 |
| agencies with usable geography | 25k-50k | 1,376 | 20,543 | 14.9 | 11.0 | 0.0 | 4.0 |  20 | 34.0 | 70.2 |   184 |
| agencies with usable geography | 50k-100k |   743 | 20,748 | 27.9 | 21.0 | 3.0 | 9.5 |  37 | 58.0 | 131.3 |   221 |
| agencies with usable geography | 100k-250k |   381 | 23,636 | 62.0 | 52.0 | 12.0 | 27.0 |  86 | 124.0 | 206.2 |   289 |
| agencies with usable geography | 250k+ |   152 | 32,299 | 212.5 | 141.5 | 46.1 | 80.0 | 231 | 465.4 | 1,176.5 | 2,442 |
| agencies with usable geography | unknown |   737 |  5,294 | 7.2 | 0.0 | 0.0 | 0.0 |   4 | 21.4 | 89.3 |   225 |

### Attributed

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  7,911 | 136,092 | 17.2 |  6 | 1.0 | 2.0 | 16.0 | 37.0 | 175.5 | 2,429 |
| agencies with >=1 camera | Municipal police |  5,913 | 101,329 | 17.1 |  6 | 1.0 | 2.0 | 16.0 | 37.0 | 157.8 | 2,429 |
| agencies with >=1 camera | Sheriff |  1,957 |  30,209 | 15.4 |  6 | 1.0 | 3.0 | 15.0 | 31.0 | 166.9 | 1,098 |
| agencies with >=1 camera | County police |     41 |   4,554 | 111.1 | 60 | 9.0 | 19.0 | 140.0 | 221.0 | 616.2 |   711 |
| agencies with usable geography | all | 14,748 | 136,067 | 9.2 |  1 | 0.0 | 0.0 | 7.0 | 21.0 | 121.5 | 2,429 |
| agencies with usable geography | Municipal police | 11,743 | 101,305 | 8.6 |  1 | 0.0 | 0.0 | 6.0 | 20.0 | 109.0 | 2,429 |
| agencies with usable geography | Sheriff |  2,962 |  30,208 | 10.2 |  3 | 0.0 | 0.0 | 9.0 | 22.0 | 135.4 | 1,098 |
| agencies with usable geography | County police |     42 |   4,554 | 108.4 | 58 | 8.1 | 15.2 | 139.8 | 219.3 | 613.8 |   711 |
| agencies with usable geography | County (type unclear) |      1 |       0 | 0.0 |  0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |     0 |

### Tagged

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  1,066 | 13,577 | 12.7 | 5 | 1 | 2 | 12.0 | 25.0 | 125.0 | 591 |
| agencies with >=1 camera | Municipal police |    887 | 11,861 | 13.4 | 5 | 1 | 2 | 12.0 | 26.4 | 138.3 | 591 |
| agencies with >=1 camera | Sheriff |    163 |  1,357 | 8.3 | 4 | 1 | 2 | 9.5 | 16.8 | 81.6 |  91 |
| agencies with >=1 camera | County police |     16 |    359 | 22.4 | 4 | 2 | 2 | 15.2 | 58.0 | 163.3 | 175 |
| agencies with usable geography | all | 14,748 | 13,552 | 0.9 | 0 | 0 | 0 | 0.0 | 0.0 | 20.0 | 591 |
| agencies with usable geography | Municipal police | 11,743 | 11,837 | 1.0 | 0 | 0 | 0 | 0.0 | 0.0 | 22.0 | 591 |
| agencies with usable geography | Sheriff |  2,962 |  1,356 | 0.5 | 0 | 0 | 0 | 0.0 | 0.0 | 12.0 |  91 |
| agencies with usable geography | County police |     42 |    359 | 8.5 | 0 | 0 | 0 | 2.0 | 14.4 | 143.0 | 175 |
| agencies with usable geography | County (type unclear) |      1 |      0 | 0.0 | 0 | 0 | 0 | 0.0 | 0.0 | 0.0 |   0 |

Per-capita columns in `agencies.csv` use FBI population served. That population is not guaranteed to match the area the located measure uses (e.g., a sheriff's population is usually the unincorporated area only, while inferred rules can add contract cities).

## 5. Historical comparison with agency-reported Flock counts

N&O "Private Eyes" data, scraped from Flock transparency portals on 2024-04-26, vs. Flock-manufacturer cameras in OSM on the pull date (2.5 years later). This shows whether the measures rank agencies sensibly. It does **not** establish current per-agency accuracy: growth, removals, mapping gaps and attribution errors all move the ratio, and the portal sample is not representative (no county police; few sheriffs).

| measure | n | r_log | spearman | median_ratio | within_2x | below_half | above_double | osm_zero |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tagged | 314 | 0.34 | 0.33 | 0.00 | 0.20 | 0.78 | 0.01 | 0.63 |
| located | 314 | 0.75 | 0.78 | 1.19 | 0.66 | 0.12 | 0.22 | 0.05 |
| attributed | 314 | 0.76 | 0.78 | 1.20 | 0.66 | 0.11 | 0.23 | 0.05 |

Located measure by group:

| group_var | group | n | median_ratio | within_2x | r_log |
| --- | --- | --- | --- | --- | --- |
| agency_type | Municipal police | 281 | 1.15 | 0.68 | 0.76 |
| agency_type | Sheriff |  33 | 1.73 | 0.48 | 0.64 |
| population_served | 10k-50k | 126 | 1.19 | 0.71 | 0.47 |
| population_served | 250k+ |   8 | 2.14 | 0.25 | 0.47 |
| population_served | 50k-250k |  95 | 1.64 | 0.61 | 0.73 |
| population_served | <10k |  82 | 1.00 | 0.68 | 0.64 |
| population_served | unknown |   3 | 1.10 | 1.00 | 0.98 |

Largest disagreements are in `validation_largest_residuals.csv` (e.g., San Diego PD: 528 reported vs 85 located; Puyallup WA PD: 2 vs 42). Plot: `validation_scatter.png`.

## 6. Limits

- **Ownership is mostly unknown.** 83.6% of cameras have no operator tag. The located and attributed measures put them with the local agency by location; some belong to HOAs, businesses, other agencies or vendors.
- **Access is not measured.** Shared networks let agencies search cameras outside their area; nothing here counts that.
- **Overlapping jurisdictions.** County, state, transit and university police operate inside cities. Cameras tagged to them are excluded from the city's located count, but untagged ones are not.
- **Uneven volunteer coverage.** A zero means none mapped (or no usable geography; see `located_zero_type`), not none installed.
- **Age of LEAIC (2012).** Place codes are old; new PDs are matched by name; mismatched codes are flagged.
- **Population served** comes from FBI records (2020-2025); 761 agencies lack it.
- **Mobile (car-mounted) ALPRs** are not in OSM.
- **Court comparisons.** Camera counts in court cases (`court_cases.md`) describe differently defined networks and are not comparable to these counts.
- No leaked or non-public Flock data were used.
