# Response to the 2026-10-03 adversarial audit

> File names below are as they were when this was written. Since then the scripts were renumbered (`04b_operator_class` -> `05_operator_class`, `06_combine_outputs` -> `07_combine_outputs`, `10_checks` -> `13_checks`), the review CSVs moved to `output/review/`, the court-case chart was withdrawn entirely (only `docs/court_cases.md` remains), and `a_in_agency_county` was dropped from `cameras.csv`.

This responds to `AUDIT_MEMO_2026-10-03.md`, which audited commit `53de8da`. Each finding was reproduced against the saved outputs before any change. All of the memo's counts reproduced exactly.

The full pipeline (`03` through `11`) was rerun after the changes. `R/10_checks.R` turns each named case from the memo into a regression check; all 16 checks pass.

## 1. Location vs. ownership vs. access (critical): accepted

The single "method B = main estimate" framing is gone. `agencies.csv` now carries three separately defined measures; definitions are at the top of `summary.md` and `R/06_combine_outputs.R`.

| Measure | What it is |
|---|---|
| `cameras_located` | Mapped cameras inside the agency's area, **excluding** cameras whose operator tag names a private party or another public body |
| `cameras_tagged` | The operator tag names the agency |
| `cameras_attributed` | Tagged cameras, plus untagged / vendor-only / unmatched-police-tag cameras located in the area. `attributed_inferred` counts the inferred part |

- **Operator classes.** A new step, `R/04b_operator_class.R`, gives every camera one class: missing, vendor, local_police, local_government, police_unmatched, public_other, private or unclassified.
  - Every operator string and its class is listed in `operator_classes_for_review.csv`.
  - Reviewed exceptions go in `R/operator_class_overrides.csv`.
- **Cameras of other operators** are excluded from the located measure: 2,560 public_other (NYC DOT, MTA, CHP, CBP, DEA, state police, universities and others) and 4,324 private.
- **NYPD:** located count fell from 1,307 to 512. The NYC DOT and MTA cameras are no longer counted.
- **Access is not measured.** The summary and plots say so explicitly.

## 2. Geographic crosswalk errors (high): fixed where demonstrable; inferred rules now flagged

- **Shared place codes.** The largest-population tie-break is removed.
  - A shared code now goes to the PD whose name matches the Census name of the code, with type words respected (a "Town" PD does not match a city polygon).
  - 7 of 8 shared codes resolve this way. The eighth (Mukwonago, WI) is left `unresolved_shared_code`.
  - **Ocean City, MD:** cameras inside Ocean City now go to Ocean City PD, not Ocean Pines (check).
- **Missing county codes.** These are now filled from the FBI directory's county name (`county_source`); 191 agencies are filled this way.
  - **St. Charles County PD:** it had county 29183 missing. It is now the county agency for 29183, with 63 located and 196 attributed cameras (check).
  - St. Charles County PD's 175 tagged cameras inside St. Charles, St. Peters and O'Fallon still count as located for those cities. That is the correct answer under a location measure, and the attributed measure gives them to the county PD.
- **Status for every camera.** `b_status` replaces `b_level`, and separates:
  - direct assignments (`direct_place`, `direct_cousub`);
  - assignments whose PD name differs from the Census name of its code (`direct_*_name_mismatch`; 862 cameras, listed in `method_b_pd_code_name_mismatches.csv`);
  - rule-based assignments (`inferred_no_pd_in_place`, `inferred_countywide_pd`);
  - unresolved and no-local-agency cameras.
  - `located_via_inferred_rule` on each agency counts the assignments that are not direct.
- **Overlapping polygons.** `n_polygon_overlaps` is recorded per camera. The count was 0 in this run.

## 3. Private-camera classification (high): fixed

- The old regex is replaced by the operator classes above.
- An operator matched to a local agency by method A is classed local_police **before** the "university"/"college" patterns run.
  - University Heights PD (18 cameras) and North College Hill PD (5 cameras) are now assigned (check).
- Meijer, Kaiser Permanente and Dierbergs Markets are now private and excluded (check). Many other retailers and businesses are also covered.
- Public universities, schools, transit and other public bodies are now `public_other`, not "private".

## 4. Agency identity (high): fixed

- **`record_status`.**
  - An ORI that is not in the current FBI directory and whose last employee-file record is before 2024 is `historical`: 212 records.
  - Historical records receive no cameras and are excluded from the statistics.
  - **Jacksonville:** FL0160200 (last report 2020) is historical. The Jacksonville Sheriff's Office now has 208 located cameras (check).
- **Agency type.** The name is now checked before the FBI type, so the four city sheriffs the FBI lists as "City" (Baltimore City, Portsmouth, Richmond, Roanoke) are Sheriffs (check).

## 5. Method A matching (high): fixed

- **Typed names.** "Town of X", "Village of X" and "Township of X" first try the typed name "X town" and its equivalents.
  - "Town of Groton Police Department" now matches Groton Town PD, CT00A5900 (check).
  - Two New York village PDs are also corrected.
- **Normalization.** "Sherrifs" and "Mt." are now normalized.
- **Labels.** "Exact" is a string operation, not proof. `jurisdiction_only` matches are classed `local_government` and reported separately.
- **Geographic corroboration.** `a_in_agency_county` flags whether a tagged camera lies in the matched agency's county.

## 6. Validation (high): accepted

- The comparison is now described as a **historical comparison** that shows ranking, not current accuracy.
- It now reports, for each measure:
  - the share within a factor of two (located: 66.2%);
  - the shares below half and above double;
  - group breakdowns by agency type and size (`validation_metrics_by_group.csv`);
  - a residual list (`validation_largest_residuals.csv`).
- Its non-representativeness is stated: no county police, and few sheriffs.

## 7. Zeros and bounds (high): accepted

- **"Floor" language is removed.** Neither the tagged nor the located measure is a bound.
- **`located_zero_type`** separates the zeros:
  - 6,798 "no mapped cameras in area";
  - 212 historical records;
  - 172 with no usable geography.
- **Statistics** are computed over current agencies only, both for agencies with ≥1 camera and for agencies with usable geography.

## 8. Court-cutoff graphic (critical): accepted

- The title "Almost every agency's camera network is smaller than ones courts have upheld" is withdrawn.
- The plot is now "Mapped ALPRs in each agency's area, with camera counts from two court cases for reference."
- The caption states that the comparison is not like-for-like: different network definitions, incomplete mapping, and shared-network access.
- It also says the chart does not show that agencies' networks are smaller.

## 9. Measurement and reproducibility (medium): partly addressed

- **Coordinates.** `n_same_coords` flags 2,391 cameras that share exact coordinates. They are not removed; they may be multi-direction installs.
- **Full OSM tags** for every camera are in `cameras_osm_tags.csv.gz`.
- **Snapshot guard.** `06_combine_outputs.R` stops if any intermediate (method A, operator class, method B) does not cover exactly the current camera set.
- **Reconciliation checks** on counts are in `10_checks.R`.
- **Run manifest.** `output/run_manifest.txt` records the sha256 of every raw input, the OSM snapshot timestamps, R and package versions, and the git commit.
- **Not done:**
  - Raw inputs are still not committed (size). The checksums identify them.
  - There is no package lockfile (renv); package versions are listed in the manifest.
  - Per-capita denominators still use FBI population served. The mismatch with the located area is stated.

## Effect on headline numbers

| | Before (53de8da) | After |
|---|---|---|
| Cameras assigned by location | 138,845 | 136,080 |
| Agencies with ≥1 located camera | 8,000 | 7,944 |
| Median located cameras (agencies with ≥1) | 6 | 6 |
| Validation, located: r on log counts | 0.753 | 0.753 |
| Validation, located: median ratio | 1.21 | 1.19 |
| Validation, located: within 2x | 66.9% | 66.2% |
| NYPD located | 1,307 | 512 |
| St. Charles County PD located / attributed | 0 / – | 63 / 196 |
| Jacksonville SO located | 0 | 208 |

The distribution changed little, because the corrected cases are concentrated in specific agencies. The individual counts the audit flagged changed substantially.
