# Adversarial audit: ALPR counts by department

Date: 2026-10-03  
For: the main implementation agent  
Repository: CharlesFainLehman/alpr-per-department  
Branch audited: `alpr-pipeline`  
Commit audited: `53de8dab484bc2b84a042aa597971b4841ad518a`

## Assessment

The saved outputs reconcile arithmetically, but they do not establish the number of cameras operated by each department. Method B counts mapped ALPR nodes allocated to agencies using geographic proxies. Those proxies contain specific errors, and camera location does not identify ownership or searchable network access.

If the intended estimand is literally cameras located in a department's service area, operator ownership is a separate question—but actual service-area boundaries still need to be established. Census place boundaries plus fallback rules do not establish them. The present results also cannot establish the size of an agency's searchable camera network.

This memo reports confirmed observations separately from methodological concerns and unverified risks. It is an audit of the above snapshot, not a claim that every discrepancy has a known correct replacement count. No analysis code or outputs were changed during the audit.

## Scope and verification

Reviewed all R scripts, the README and task specification, and the saved summary. Independently loaded the complete camera and agency CSVs, operator crosswalk, selected geographic exception files, FBI roster, and validation outputs. Also inspected the original McClatchy validation CSV.

Confirmed:

- 143,157 camera rows and 143,157 distinct OSM IDs.
- 15,126 agency rows and 15,126 distinct ORIs.
- Every agency's `cameras_a`, `cameras_b`, `flock_a`, and `flock_b` reconciles with grouping the camera file by the corresponding assignment.
- Totals: A 13,550; B 138,845; Flock A 9,858; Flock B 111,422.
- All 314 matched validation rows have distinct ORIs. The code's ability to retain duplicate validation matches did not cause duplication in this run.
- Method B validation correlations reproduce: Pearson 0.625610; Spearman 0.781518; Pearson on log1p counts 0.752641.
- The original validation file has 365 rows, all with an `updated` date of 2024-04-26. The repository is correct that the filename's “2023” does not identify the observation date.

The geographic pipeline was not rerun from raw inputs. Most raw OSM, Census, and FBI downloads and derived spatial files are not committed. Counts below were recomputed from saved outputs; upstream geographic predicates were inspected in source, not independently rerun.

All repository paths below refer to the audited commit. Immutable source prefix:
https://github.com/CharlesFainLehman/alpr-per-department/blob/53de8dab484bc2b84a042aa597971b4841ad518a/

## 1. Critical: location, operation, and access are different estimands

Source: `R/05_method_b.R`, especially final assignment at lines 117–139; `output/cameras.csv`.

Method B assigns a camera to a local agency based on geography even when its operator tag identifies a different public body. Of 138,845 B-assigned cameras, 86.0% have a missing operator tag.

A/B comparisons:

| Result | Cameras |
| --- | ---: |
| B only | 125,335 |
| Agree | 12,363 |
| Neither | 4,272 |
| Disagree | 1,147 |
| A only | 40 |

The 1,147 disagreements are 8.49% of the 13,510 cameras assigned by both methods. This is a disagreement rate, not an independently measured Method B error rate: contracts can explain some differences and Method A also makes errors.

Concrete evidence:

- NYPD's B count of 1,307 includes 593 cameras tagged “NYC Department of Transportation,” 28 tagged “New York City Department of Transportation,” and 19 tagged “NYC D.O.T”: 640 explicitly DOT-tagged cameras.
- B-assigned cameras with no A match include 402 tagged “California Highway Patrol (CHP),” another 50 tagged “California Highway Patrol,” 86 tagged “Customs and Border Protection,” and 64 tagged “University of Arizona Police Department.”
- The operator string “St. Charles County PD” produces numerous disagreements, including 48 assigned by B to St. Charles city PD, 38 to the county sheriff, and 34 to St. Peters PD.

These are not ownership estimates merely needing wider confidence intervals. Ownership is unidentified for most rows. Unknown/private/public-other ownership should remain distinct from geographic exposure.

For the main agent: establish separate fields and claims for (a) mapped location within a defined area, (b) verified or inferred operator, and (c) access to shared records. Preserve explicit other-operator evidence. An operator match should not silently redefine the geographic measure, but geographic allocation should not be labeled ownership.

## 2. High: geographic crosswalk rules produce identifiable wrong allocations

Source: `R/05_method_b.R`, lines 65–139; `output/method_b_places_with_multiple_pds.csv`; `output/agencies.csv`.

### Ocean City / Ocean Pines

Both agencies carry place FIPS `2458225`. The script chooses the agency with the larger FBI population:

- Ocean Pines, ORI `MD0240500`: population 12,272, B count 6.
- Ocean City, ORI `MD0240200`: population 6,893, B count 0.

Three of the six cameras assigned to Ocean Pines explicitly name Ocean City Police Department as operator. Census identifies `2458225` as Ocean City town:

https://tigerweb.geo.census.gov/tigerwebmain/Files/acs26/tigerweb_acs26_incplace_2025_acs25_md.html

This proves that “choose the largest population” does not resolve bad/shared geographic codes. Validate the entity named by the code; do not award a disputed polygon on population alone.

### St. Charles County

St. Charles County Police Department (`MO0922400`) has A count 175 and B count 0. Its county FIPS is missing. St. Charles County Sheriff's Office has county FIPS `29183`, population 0, and B count 63.

The code excludes county agencies without county FIPS before constructing the county assignment. Missing crosswalk coverage thus creates a zero for the PD and routes cameras to other agencies. The A count is evidence of the failure, not proof that 175 is the complete correct inventory.

### Fallback assumptions

- 4,030 cameras use `place_without_pd_to_county`. Failure to find a PD is not proof of sheriff service: a code may be missing, outdated, or wrong, or a regional/contract agency may serve the place.
- Municipal PDs are deemed countywide when FBI population is at least 50% of county ACS population. That numerical condition does not establish countywide jurisdiction.
- The countywide rules assign 641 cameras through `countywide_pd_no_county_agency` and 433 through `consolidated_countywide_pd`. Those are counts affected by the heuristic, not counts proven incorrect.
- Places and county subdivisions are matched against the same reduced state-plus-five-digit key. Entity identity and county context deserve validation rather than assuming every accepted code denotes the intended service area.
- Polygon overlaps are resolved by the first intersecting polygon, making assignment depend on ordering. The output does not retain candidate polygons or a per-camera ambiguity flag.

For the main agent: distinguish confirmed service relationships from unresolved crosswalks; retain uncertainty rather than converting missing geography to a county assignment.

## 3. High: private-camera classification has observed false positives and false negatives

Source: `R/05_method_b.R`, lines 24–38; `output/cameras.csv`.

The private-name regex includes “university” and “college.” Its public-agency exception recognizes “police” or “sheriff,” but not “PD.”

Confirmed false exclusions:

- All 18 cameras tagged “University Heights PD” are excluded as private. Method A assigns them to University Heights Police Department, Ohio, whose B count is zero. Seventeen have surveillance “traffic” and one “public.”
- Five tagged “North College Hill PD” are also excluded.

Confirmed private-operator strings surviving B's filter and being assigned to local agencies:

| Operator string | Cameras |
| --- | ---: |
| Meijer | 77 |
| Kaiser Permanente | 70 |
| Dierbergs Markets | 50 |

The problem therefore extends beyond untagged private cameras. Clear operator information is being mishandled.

Public university and school agencies also should not automatically be labeled “private”: out-of-scope public agencies and private operators are different categories. The opposite exception can retain university police cameras when “police” occurs in the name, reallocating them to local departments.

For the main agent: use a reviewed operator classification table and normalized agency recognition; distinguish private, public-local, public-other, vendor-only, and unknown. Test the observed University Heights and North College Hill cases.

## 4. High: the roster includes historical reporting records without resolving current agency identity

Source: `R/03_agencies.R`; `data/derived/agencies_fbi.csv`; `output/agencies.csv`.

The roster full-joins CDE to each ORI's most recent employee-file record since 2020. There are 313 resulting agencies without a CDE name. Absence from CDE does not itself prove inactivity, but inclusion also does not establish that these are distinct current agencies.

Jacksonville is a concrete failure of unresolved identity:

| ORI | Source/status in input | Population/year | B count |
| --- | --- | --- | ---: |
| FL0160000 | CDE: Jacksonville Sheriff's Office | 1,008,920 / 2025 | 0 |
| FL0160200 | No CDE record; LEE name “Jacksonville” | 920,508 / 2020 | 211 |

The older City-type record receives the place assignment, splitting the current policing entity across reporting identities. This affects both the agency's count and the national agency denominator.

The code also treats FBI type “City” as municipal police before inspecting sheriff names; four saved municipal-police rows contain “sheriff” in the name. Type and organizational identity need review.

For the main agent: resolve historical/current ORI relationships, active status, contract reporting units, and actual departments. Retain provenance and unresolved-status flags rather than silently counting every ORI as a contemporary independent department.

## 5. High: deterministic Method A matches can be false

Source: `R/04_method_a.R`, especially lines 38–54 and 76–89; `output/method_a_operator_crosswalk.csv`.

The parser strips “Town of” and “City of,” while other agency-name forms retain “Town” in the initial matching core.

Observed example:

- All 10 cameras tagged “Town of Groton Police Department” are assigned to `CT0005900`, Groton Police Department (the city).
- The separate town agency is `CT00A5900`, Groton Town Police Department.
- The incorrect assignment is labeled `exact`, so reviewing only fuzzy matches does not catch it.

A total of 1,020 cameras are assigned through `jurisdiction_only`: a government/place name is treated as its police operator. Such assignments are inferred, not verified ownership.

For the main agent: preserve meaningful city/town/township distinctions and use geographic corroboration to disambiguate identity, with explicit exceptions. Audit deterministic and jurisdiction-only matches as well as fuzzy candidates. “Exact” describes a normalized-string operation, not evidentiary certainty.

## 6. High: validation supports rank association, not reliable individual inventories

Source: `R/07_validate.R`; `output/validation_comparison.csv`; original source:
https://github.com/mcclatchy-southeast/private_eyes/blob/main/data/latest_usage04262023.csv

The reported correlations reproduce. Nevertheless, among the 308 matched agencies with positive reported inventories:

- 206 (66.9%) have B counts within a factor of two, inclusive.
- 34 have B counts below half the reported inventory.
- 68 have B counts above twice the reported inventory.

The matched validation sample includes 281 municipal-police records and 33 sheriffs; no county-police records. Median B/reported ratios are approximately 1.17 for municipal police and 1.73 for sheriffs.

Examples:

| Agency | Reported Flock cameras, 2024 | B-assigned Flock cameras, 2026 |
| --- | ---: | ---: |
| San Diego CA PD | 528 | 85 |
| El Cerrito CA PD | 40 | 0 |
| Puyallup WA PD | 2 | 42 |
| Santa Clara County CA SO | 80 | 19 |

These discrepancies are real comparisons, not proven current inventory errors of those magnitudes. Growth, removal, mapping coverage, attribution, and source reporting can all contribute. The two-and-a-half-year mismatch prevents interpreting the metrics as contemporary accuracy. Higher later counts cannot be justified simply by saying growth is expected.

The convenience sample of transparency portals does not establish national representativeness, especially for zeros or geographic/agency types poorly represented. Correlation may also reflect common scaling with jurisdiction size.

For the main agent: inspect large residuals and matching validity; report ratio/error distributions by agency type and size; distinguish historical comparison from contemporaneous validation. Avoid presenting the current correlations as proof of accurate department inventories.

## 7. High: zeros and lower-bound language are unsupported

Source: `R/06_combine_outputs.R`; `R/08_summary.R`; `output/summary.md`.

Method B reports zero for 7,126 agencies. Zero conflates:

- No mapped cameras.
- No usable agency geography.
- Exclusion/classification mistakes.
- Losing a shared-geography allocation.
- Historical or duplicate agency identities.
- Potentially genuine absence.

Eighteen agencies have positive A counts but zero B counts. The examples above demonstrate why “zero” cannot automatically mean no cameras even within this dataset.

Method A is described as a floor. Because wrong agency matches can add cameras, it is not a guaranteed lower bound. Method B is neither an upper nor a lower bound: it both omits and incorrectly includes cameras.

For the main agent: separate missing/unresolved coverage from observed mapped zero. National distributions should explicitly describe mapped allocations, with agency-eligibility and crosswalk-coverage status. Neither method currently supplies identified population bounds.

## 8. Critical for the published graphic: geographic counts do not measure searchable networks

Source: `R/09_density_court_cutoff.R`.

The title states: “Almost every agency's camera network is smaller than ones courts have upheld.” The plotted variable is Method B geographic allocation. The reference lines use differently constituted networks, including a statewide agency's installations and a countywide collection of cameras associated with multiple operators.

Even if every cited legal description is correct, this is a unit-of-analysis mismatch. It is not established by comparing these quantities that nearly every agency has a smaller network. Incomplete mapping further weakens a claim that a true network is below a numerical cutoff.

Flock's own description distinguishes direct sharing and National Lookup:
https://www.flocksafety.com/blog/statement-network-sharing-use-cases-federal-cooperation

An agency's searchable records can extend beyond cameras physically within its area. This audit did not independently re-review the cited court opinions or confirm current appellate status. The objection here is methodological and does not depend on reversing any legal holding.

For the main agent: withdraw or reframe the network-size conclusion. A count threshold alone also does not establish equivalence between the practices, coverage, and queries considered in different cases.

## 9. Additional measurement and reproducibility risks

### OSM nodes are not a verified physical inventory

Source: `R/02_pull_osm.R`.

The query retrieves nodes with two exact tags and deduplicates OSM IDs. There are 1,275 rows beyond the first at identical latitude/longitude pairs. These may be legitimate distinct devices or directions; they are inspection candidates, not confirmed duplicates.

No demonstrated audit establishes physical-device uniqueness, continued operation, or coverage of every relevant mapping convention. Last-edit time does not establish installation date or current operation. The code preserves raw tags locally but the published camera CSV omits the full tag set, limiting review of lifecycle/status information.

### Boundary ambiguity

Source: `R/02_pull_osm.R` and `R/05_method_b.R`.

First-intersection selection is used for overlapping/boundary cases. The memo does not assert a measured number of incorrect boundary assignments: the underlying spatial layers and ambiguity logs were not independently replayed. Retain flags/candidates and quantify sensitivity rather than treating the first polygon as certain.

### Per-capita denominators

Source: `R/06_combine_outputs.R`.

FBI population served is not demonstrated to correspond to the exact territory assigned by Method B. This matters especially when incorporated places fall to a county agency or agencies share service arrangements. Population years range from 2020 through 2025; 761 agency populations are missing. There are 141 zero-population records, of which 46 receive positive B camera counts.

The code appropriately avoids positive per-capita rates for zero populations, but that does not validate the remaining geographic numerator/denominator pairs.

### Reproduction and stale intermediate files

Most raw inputs and spatial intermediates are absent from git, and there is no package lockfile. The raw LEAIC TSV is committed; the issue is not that every raw source is absent. Rerunning the live OSM query creates a new snapshot, not the audited one.

The combine script decides whether B exists from file existence, not an input-snapshot identity. A partial rerun can potentially combine new cameras with stale A/B intermediates without a row-count failure. This is a code-path risk, not an observed defect in the audited saved outputs.

Archive immutable inputs with checksums, package versions, a run manifest, and snapshot IDs on intermediate artifacts. Reject incompatible snapshots and assert key uniqueness, referential integrity, and count conservation for both methods.

## Review priorities

1. Agree on the estimand and correct the ownership/network language.
2. Repair the demonstrated geographic, private-filter, agency-identity, and name-normalization errors.
3. Preserve unresolved assignments as unresolved rather than converting them to county allocations or meaningful zeros.
4. Recompute outputs and quantify how the fixes change distributions and validation.
5. Reassess validation and any network/court comparison against the corrected measurement definition.

The demonstrated examples should become regression checks. They are not a comprehensive list of all affected agencies.

## Minimal reproduction of the principal quantitative checks

Run from the repository root with Python, pandas, and NumPy. This recomputes checks against whichever outputs are present; the numbers in this memo refer only to the audited commit.

```python
import numpy as np
import pandas as pd

c = pd.read_csv("output/cameras.csv")
a = pd.read_csv("output/agencies.csv")
v = pd.read_csv("output/validation_comparison.csv")

assert len(c) == c.osm_id.nunique()
assert len(a) == a.ori.nunique()

for assignment, total, flock_total in [
    ("a_ori", "cameras_a", "flock_a"),
    ("b_ori", "cameras_b", "flock_b"),
]:
    for rows, column in [(c, total), (c[c.is_flock], flock_total)]:
        counts = rows.groupby(assignment).size()
        saved = a.set_index("ori")[column]
        assert saved.eq(counts.reindex(saved.index, fill_value=0)).all()

print(c.a_b_compare.value_counts())
print("Zero B agencies:", a.cameras_b.eq(0).sum())
print("Positive A, zero B:", (a.cameras_a.gt(0) & a.cameras_b.eq(0)).sum())
print("Repeated-coordinate excess rows:", c.duplicated(["lat", "lon"]).sum())
print("B missing-operator share:", c.loc[c.b_ori.notna(), "operator"].isna().mean())

positive = v[v.reported > 0]
ratio = positive.osm_b / positive.reported
print("Positive-report N:", len(positive))
print("Within factor two:", ratio.between(0.5, 2).sum())
print("Below half / above twice:", ratio.lt(0.5).sum(), ratio.gt(2).sum())
print("Pearson:", v.osm_b.corr(v.reported))
print("Spearman:", v.osm_b.corr(v.reported, method="spearman"))
print("Log Pearson:", np.log1p(v.osm_b).corr(np.log1p(v.reported)))

print(a[a.ori.isin([
    "MD0240500", "MD0240200", "MO0922400", "MO0920000",
    "FL0160000", "FL0160200", "CT0005900", "CT00A5900"
])].to_string(index=False))
print(c[c.operator.eq("University Heights PD")]
      .groupby(["b_excluded", "a_name"], dropna=False).size())
print(c[c.b_ori.notna() & c.operator.isin([
    "Meijer", "Kaiser Permanente", "Dierbergs Markets"
])].groupby("operator").size())
```
