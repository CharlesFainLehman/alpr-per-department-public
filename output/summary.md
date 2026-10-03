# Mapped ALPRs per US local police agency: summary

OSM pull 2026-10-03 (Overpass; OSM base timestamps 2026-10-03 13:08:13 to 2026-10-03 15:24:51). Agencies: FBI CDE directory + FBI employee file (population served) + BJS LEAIC 2012. Boundaries: TIGER/Line 2025. Population: ACS 2020-2024 5-year.

**What these numbers are.** Counts of license plate reader cameras *mapped* in OpenStreetMap (the crowdsourced layer DeFlock maintains), tied to local agencies three ways. None is a verified inventory of cameras an agency owns, and none measures what an agency can *search*: through shared networks (e.g., Flock sharing and national lookup) an agency can query cameras far outside its own area. Neither the tagged nor the located measure is a lower or upper bound: both omit some cameras and include some wrongly.

| Measure | Definition |
| --- | --- |
| **Located** | Cameras inside the agency's area (incorporated place, town/township, or the county outside them), excluding cameras whose operator tag names a private party or another public body (DOT, transit, state police, federal, university, school). Includes cameras with no operator tag. |
| **Tagged** | Cameras whose `operator` tag names the agency (name match within the state). |
| **Attributed** | Tagged cameras, plus cameras with no operator, a vendor-only tag ("Flock Safety"), or an unmatched police tag that are located in the agency's area (inferred). |

## 1. Camera data

- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), 50 states + DC: **143,157**. 2,391 rows share exact coordinates with another node (possible duplicates or multi-direction installs; flagged `n_same_coords`, not removed).
- With an `operator` tag: **23,450 (16.4%)**.
- By manufacturer (spelling variants grouped; full list `osm_counts_by_manufacturer.csv`):

| manufacturer | cameras | share |
| --- | --- | --- |
| Flock | 111,315 | 77.8% |
| Motorola / Vigilant |   7,372 | 5.1% |
| Genetec |   3,465 | 2.4% |
| Axis |   2,981 | 2.1% |
| Leonardo / ELSAG |   1,242 | 0.9% |
| Rekor |     824 | 0.6% |
| Axon |     755 | 0.5% |
| PlateSmart |     745 | 0.5% |
| (no manufacturer tag) |  11,102 | 7.8% |

- Operator class (rules in `R/05_operator_class.R`; every string and its class in `review/operator_classes_for_review.csv`):

| operator_class | cameras | share |
| --- | --- | --- |
| missing | 119,610 | 83.6% |
| local_police |  12,549 | 8.8% |
| private |   4,413 | 3.1% |
| public_other |   2,644 | 1.8% |
| vendor |   2,171 | 1.5% |
| local_government |   1,029 | 0.7% |
| police_unmatched |     394 | 0.3% |
| unclassified |     347 | 0.2% |

## 2. Agency list

- 15,131 local agencies in the table: 12,094 municipal police, 2,989 sheriffs, 46 county police, 2 unclear.
- 216 are **historical** records (not in the current FBI directory; last employee report before 2024). They stay in `agencies.csv`, flagged, but get no cameras and are excluded from the statistics below. 14,915 current agencies remain.
- Geography: 14,749 current agencies have a usable place or county code; 166 do not (`geo_status`).
- Population served comes from FBI records (2020-2025); 761 agencies lack it.

## 3. How cameras were placed (located measure)

| b_status | cameras |
| --- | --- |
| direct_place | 93,286 |
| county_unincorporated | 30,364 |
| direct_cousub |  6,153 |
| excluded_private |  4,413 |
| inferred_no_pd_in_place |  4,168 |
| excluded_public_other |  2,644 |
| inferred_countywide_pd |  1,076 |
| direct_place_name_mismatch |    797 |
| no_local_agency |    192 |
| direct_cousub_name_mismatch |     63 |
| unresolved_shared_code |      1 |

- `direct_*_name_mismatch`: the PD's LEAIC code points to a Census entity with a different name (spelling, consolidated governments, or a wrong code); listed in `review/method_b_pd_code_name_mismatches.csv`.
- `inferred_*`: assignment by rule, not verified (city with no PD in the list -> county agency; consolidated government or county with no county agency -> county-wide PD).
- `unresolved_shared_code`: two PDs share a code and the name does not decide it. `no_local_agency`: state-police areas.

Agencies with zero located cameras, by reason:

| reason | agencies |
| --- | --- |
| no mapped cameras in area | 6,808 |
| historical record (not assigned) |   216 |
| no usable geography: no_usable_place_code |   131 |
| no usable geography: county_shared_other_agency_assigned |    26 |
| no usable geography: place_code_shared_not_assigned |     9 |

## 4. Cameras per agency (current agencies)

Agencies with at least one camera under each measure:

| measure | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| located | 7,941 | 135,907 | 17.1 | 6 | 1 | 2 | 16 | 36 | 174.4 | 2,442 |
| attributed | 7,907 | 135,914 | 17.2 | 6 | 1 | 2 | 16 | 36 | 175.7 | 2,429 |
| tagged | 1,065 |  13,573 | 12.7 | 5 | 1 | 2 | 12 | 25 | 125.2 |   591 |

Located measure by agency type and by population served (`summary_stats.csv` has the same split for the other measures):

| set | group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies with >=1 camera | all |  7,941 | 135,907 | 17.1 | 6.0 | 1 | 2.0 |  16 | 36.0 | 174.4 | 2,442 |
| agencies with >=1 camera | Municipal police |  5,940 | 101,375 | 17.1 | 6.0 | 1 | 2.0 |  16 | 37.0 | 157.2 | 2,442 |
| agencies with >=1 camera | Sheriff |  1,960 |  30,112 | 15.4 | 6.0 | 1 | 3.0 |  15 | 31.0 | 163.9 | 1,101 |
| agencies with >=1 camera | County police |     41 |   4,420 | 107.8 | 60.0 | 8 | 19.0 | 138 | 221.0 | 615.4 |   711 |
| agencies with usable geography | all | 14,749 | 135,907 | 9.2 | 1.0 | 0 | 0.0 |   7 | 21.0 | 121.5 | 2,442 |
| agencies with usable geography | Municipal police | 11,744 | 101,375 | 8.6 | 1.0 | 0 | 0.0 |   6 | 20.0 | 109.6 | 2,442 |
| agencies with usable geography | Sheriff |  2,962 |  30,112 | 10.2 | 3.0 | 0 | 0.0 |   9 | 22.0 | 135.4 | 1,101 |
| agencies with usable geography | County police |     42 |   4,420 | 105.2 | 58.5 | 8 | 15.2 | 136 | 219.2 | 613.0 |   711 |
| agencies with usable geography | County (type unclear) |      1 |       0 | 0.0 | 0.0 | 0 | 0.0 |   0 | 0.0 | 0.0 |     0 |

| group | agencies | cameras | mean | median | p10 | p25 | p75 | p90 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <2.5k |   938 |  3,119 | 3.3 |   2 |  1 | 1.0 |   4 |   6 | 20.0 |   189 |
| 2.5k-10k | 2,158 | 10,940 | 5.1 |   4 |  1 | 2.0 |   6 |  11 | 27.4 |    59 |
| 10k-25k | 2,060 | 19,480 | 9.5 |   7 |  1 | 3.0 |  13 |  20 | 45.4 |    71 |
| 25k-50k | 1,231 | 20,503 | 16.7 |  13 |  3 | 6.0 |  22 |  35 | 71.7 |   184 |
| 50k-100k |   718 | 20,709 | 28.8 |  22 |  5 | 11.0 |  38 |  58 | 132.3 |   219 |
| 100k-250k |   380 | 23,597 | 62.1 |  52 | 12 | 27.0 |  85 | 124 | 206.3 |   289 |
| 250k+ |   151 | 32,268 | 213.7 | 143 | 46 | 81.5 | 231 | 464 | 1,178.0 | 2,442 |
| unknown |   305 |  5,291 | 17.3 |   6 |  1 | 2.0 |  21 |  48 | 128.3 |   225 |

Per-capita columns in `agencies.csv` use FBI population served, which need not match the area the located measure uses (a sheriff's population is usually the unincorporated area only; inferred rules can add contract cities).

## 5. Historical comparison with agency-reported Flock counts

N&O "Private Eyes" data, scraped from Flock transparency portals on 2024-04-26, vs. Flock-manufacturer cameras in OSM on the pull date (2.4 years later). This shows whether the measures rank agencies sensibly. It does **not** establish current per-agency accuracy: growth, removals, mapping gaps and attribution errors all move the ratio, and the portal sample is not representative (281 municipal police, 33 sheriff).

| measure | n | r_log | spearman | median_ratio | within_2x | below_half | above_double | osm_zero | median_abs_error |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tagged | 314 | 0.34 | 0.33 | 0.00 | 0.20 | 0.78 | 0.01 | 0.63 | 9 |
| located | 314 | 0.75 | 0.78 | 1.19 | 0.66 | 0.12 | 0.22 | 0.05 | 6 |
| attributed | 314 | 0.76 | 0.78 | 1.20 | 0.66 | 0.11 | 0.23 | 0.05 | 6 |

Largest disagreements (located measure) are in `validation_largest_residuals.csv`, e.g. El Cerrito CA PD: 40 reported vs 0 located; Puyallup WA PD: 2 vs 42. Plot: `validation_scatter.png`.

## 5b. Comparison with publicly reported counts (web-collected; sources dated 2016-2026)

Collected from agency websites, government documents and news articles quoting officials (`data/validation_web/`, one row per agency with URL and quote). The Flock transparency portals themselves block automated access and were not used directly. Rows are flagged for discontinued programs, planned/contracted counts, counts of locations rather than cameras, and figures that include mobile or shared cameras; the core comparison uses only current programs with a fixed, agency-operated camera count. Attributed-measure results (not shown) are within 0.01 of the located ones.

| subset | n | r_log | median_ratio | within_2x | below_half | above_double |
| --- | --- | --- | --- | --- | --- | --- |
| core: current, fixed, agency-operated | 360 | 0.81 | 1.14 | 0.77 | 0.07 | 0.16 |
| core, excluding agencies reporting zero | 342 | 0.85 | 1.14 | 0.77 | 0.07 | 0.16 |
| fixed, source dated 2025-2026 | 337 | 0.81 | 1.13 | 0.77 | 0.07 | 0.16 |
| municipal police | 293 | 0.83 | 1.13 | 0.79 | 0.07 | 0.14 |
| sheriffs / county police |  67 | 0.76 | 1.21 | 0.67 | 0.08 | 0.25 |
| figures incl. mobile/shared or unclear | 155 | 0.76 | 1.08 | 0.68 | 0.15 | 0.18 |
| discontinued programs (last count) | 115 | 0.61 | 0.76 | 0.59 | 0.29 | 0.12 |
| planned / contracted counts |  69 | 0.76 | 1.18 | 0.64 | 0.16 | 0.20 |

Agencies that report owning **zero** fixed cameras (18 in the core set; e.g., Charlotte-Mecklenburg Police Department 255, Durham Police Department 65) often have mapped cameras in their area run by other parties (HOAs, businesses, neighboring agencies). The located measure cannot tell those apart, which is the largest source of disagreement.

### Reported counts as an independent estimate of camera density

For the core agencies, reported counts and OSM give a similar per-capita picture. The OSM count runs higher for the largest agencies (median ratio 1.92 for 250k+), where the located measure also picks up untagged cameras of other operators. The web sample is not random: it contains only agencies with cameras whose count was published, so it cannot estimate how many agencies have none, and it leans toward larger and contested programs. Plots: `validation_web_scatter.png`, `hist_web_sample_reported_vs_osm.png`.

| estimate | agencies | mean | median | p25 | p75 | p90 | max |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reported count (web sources) | 360 | 35.0 | 16.0 | 7.0 | 34.0 | 79.1 | 553.0 |
| OSM located, same agencies | 360 | 52.5 | 20.0 | 9.0 | 49.0 | 105.4 | 2,240.0 |
| reported per 10,000 residents | 359 | 7.0 | 3.9 | 1.8 | 7.2 | 13.0 | 222.5 |
| OSM located per 10,000 residents, same agencies | 359 | 6.9 | 4.7 | 2.5 | 8.1 | 13.3 | 73.9 |

| size | agencies | median_reported | median_osm_located | median_reported_per10k | median_osm_per10k | median_ratio_osm_to_reported |
| --- | --- | --- | --- | --- | --- | --- |
| <10k |  48 | 6.00 |   5 | 10.63 | 10.63 | 0.88 |
| 10k-50k | 150 | 11.50 |  13 | 4.84 | 5.15 | 1.00 |
| 50k-250k | 121 | 26.00 |  37 | 2.85 | 3.80 | 1.27 |
| 250k+ |  41 | 100.00 | 141 | 2.25 | 3.30 | 1.92 |

## 5c. Minnesota BCA register of fixed LPR locations

Minnesota agencies must report to the state Bureau of Criminal Apprehension where their stationary LPRs are; the BCA publishes the list (`data/validation_web/mn_bca_fixed_lpr_locations.csv`). This is a separate check: the register counts **locations, not cameras** (one location can hold several readers, e.g. one per direction), so a ratio above 1 is expected even with complete mapping. Local agencies that withheld their locations (3) and non-local agencies (4: State Patrol, tribal, university and airport police) are left out. Compared with all-vendor OSM located counts. `median_ratio` and `within_2x` use only agencies listing at least one location; the zero-listing agencies change only the correlations.

| subset | n | n_listing_zero | r_log | spearman | median_ratio | within_2x | below_half | above_double |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| agencies listing >=1 fixed location |  83 |  0 | 0.53 | 0.58 | 1.16 | 0.65 | 0.14 | 0.20 |
| including agencies listing zero fixed locations | 110 | 27 | 0.60 | 0.63 | 1.16 | 0.65 | 0.14 | 0.20 |

Of the 27 agencies that list no fixed locations, 14 have no mapped cameras in their area and 13 have some (largest: St. Paul Police Department 45; Eden Prairie Police Department 36). Those are either cameras of other operators or gaps in the register.

## 6. Limits

- **Ownership is mostly unknown.** 83.6% of cameras have no operator tag. The located and attributed measures put them with the local agency by location; some belong to HOAs, businesses, other agencies or vendors.
- **Access is not measured.** Shared networks let agencies search cameras outside their area; nothing here counts that.
- **Overlapping jurisdictions.** County, state, transit and university police operate inside cities. Cameras tagged to them are excluded from the city's located count, but untagged ones are not.
- **Uneven volunteer coverage.** A zero means none mapped (or no usable geography; see `located_zero_type`), not none installed.
- **Age of LEAIC (2012).** Place codes are old; new PDs are matched by name; mismatched codes are flagged.
- **Mobile (car-mounted) ALPRs** are not in OSM.
- **Court comparisons.** Camera counts in court cases (`docs/court_cases.md`) describe differently defined networks and are not comparable to these counts.
- No leaked or non-public Flock data were used.
