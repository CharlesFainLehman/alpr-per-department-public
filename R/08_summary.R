# Write output/summary.md from the saved outputs.
source("R/00_setup.R")

md_table <- function(d, digits = 1) {
  d <- d |> mutate(across(where(\(x) is.double(x) && all(x == round(x), na.rm = TRUE)), as.integer),
                   across(where(is.double), \(x) formatC(x, format = "f", digits = digits, big.mark = ",")),
                   across(where(is.integer), \(x) format(x, big.mark = ",")))
  c(paste("|", paste(names(d), collapse = " | "), "|"),
    paste("|", paste(rep("---", ncol(d)), collapse = " | "), "|"),
    apply(d, 1, \(r) paste("|", paste(r, collapse = " | "), "|")))
}
f <- \(x) format(x, big.mark = ",")
pct <- \(x) sprintf("%.1f%%", 100 * x)

cams <- read_csv(file.path(OUT, "cameras.csv"), col_types = cols(.default = "c"))
ags  <- read_csv(file.path(OUT, "agencies.csv"), show_col_types = FALSE)
st   <- read_csv(file.path(OUT, "summary_stats.csv"), show_col_types = FALSE)
vm   <- read_csv(file.path(OUT, "validation_metrics.csv"), show_col_types = FALSE)
vg   <- read_csv(file.path(OUT, "validation_metrics_by_group.csv"), show_col_types = FALSE)
mf   <- read_csv(file.path(OUT, "osm_counts_by_manufacturer.csv"), show_col_types = FALSE)
pull_date <- readLines(file.path(PROC, "osm_pull_date.txt"))
ql <- read_csv(list.files(file.path(RAW, "osm", pull_date), "query_log.csv", full.names = TRUE), show_col_types = FALSE)
cur <- ags |> filter(record_status != "historical")

n <- nrow(cams)
fam <- function(rx) sum(mf$n[str_detect(str_to_lower(mf$manufacturer), rx)])
man <- tibble(manufacturer = c("Flock", "Motorola / Vigilant", "Genetec", "Axis", "Leonardo / ELSAG", "Rekor", "Axon",
                               "PlateSmart", "(no manufacturer tag)"),
              rx = c("flock", "motorola|vigilant", "genetec", "axis", "leonardo|elsag", "rekor", "axon", "platesmart", "^\\(none\\)$")) |>
  mutate(cameras = map_int(rx, fam), share = pct(cameras / n)) |> select(-rx)
tagged_op <- sum(cams$op_class != "missing")

opc <- cams |> count(operator_class = op_class, name = "cameras") |> arrange(desc(cameras)) |> mutate(share = pct(cameras / n))
bst <- cams |> count(b_status, name = "cameras") |> arrange(desc(cameras))
att <- cams |> count(attr_basis = coalesce(attr_basis, "(not attributed)"), name = "cameras") |> arrange(desc(cameras))
zero <- ags |> filter(cameras_located == 0) |> count(reason = located_zero_type, name = "agencies") |> arrange(desc(agencies))

stat_cols <- c("agencies", "cameras", "mean", "median", "p10", "p25", "p75", "p90", "p99", "max")
BIN_ORDER <- c("all", "Municipal police", "Sheriff", "County police", "County (type unclear)",
               "<2.5k", "2.5k-10k", "10k-25k", "25k-50k", "50k-100k", "100k-250k", "250k+", "unknown")
tab <- function(m, sets, gv) st |> filter(measure == m, set %in% sets, group_var %in% gv) |>
  select(set, group, all_of(stat_cols)) |> arrange(set, match(group, BIN_ORDER))
SETS <- c("agencies with >=1 camera", "agencies with usable geography")

vt <- vm |> transmute(measure, n, r_log = pearson_r_log1p, spearman = spearman_rho,
                      median_ratio = median_ratio_osm_over_reported, within_2x = share_within_factor_2,
                      below_half = share_below_half, above_double = share_above_double, osm_zero = share_osm_zero)
vgt <- vg |> transmute(group_var, group, n, median_ratio = median_ratio_osm_over_reported,
                       within_2x = share_within_factor_2, r_log = pearson_r_log1p)

out <- c(
"# Mapped ALPRs per US local police agency: summary", "",
sprintf("OSM pull %s (Overpass; OSM base timestamps %s to %s). Agencies: FBI CDE directory + FBI employee file (population served) + BJS LEAIC 2012. Boundaries: TIGER/Line %d. Population: ACS 2020-2024 5-year.",
        pull_date, min(ql$osm_base), max(ql$osm_base), TIGER_YEAR), "",
"**What these numbers are.** Counts of license plate reader cameras *mapped* in OpenStreetMap (the crowdsourced layer DeFlock maintains), tied to local agencies three ways. None is a verified inventory of cameras an agency owns, and none measures what an agency can *search*: through shared networks (e.g., Flock sharing and national lookup) an agency can query cameras far outside its own area. Neither the tagged nor the located measure is a lower or upper bound: both omit some cameras and include some wrongly.", "",
"| Measure | Definition |", "| --- | --- |",
"| **Located** | Cameras inside the agency's area (incorporated place, town/township, or the county outside them), excluding cameras whose operator tag names a private party or another public body (DOT, transit, state police, federal, university, school). Includes cameras with no operator tag. |",
"| **Tagged** | Cameras whose `operator` tag names the agency (name match within the state). |",
"| **Attributed** | Tagged cameras, plus cameras with no operator, a vendor-only tag (\"Flock Safety\"), or an unmatched police tag that are located in the agency's area (inferred). |", "",
"Changes since the first version follow the 2026-10-03 audit; see `AUDIT_RESPONSE.md`.", "",
"## 1. Camera data", "",
sprintf("- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), 50 states + DC: **%s**. %s rows share exact coordinates with another node (possible duplicates or multi-direction installs; flagged `n_same_coords`, not removed).", f(n), f(sum(as.integer(cams$n_same_coords) > 1))),
sprintf("- With an `operator` tag: **%s (%s)**.", f(tagged_op), pct(tagged_op / n)),
"- By manufacturer (spelling variants grouped; full list `osm_counts_by_manufacturer.csv`):", "",
md_table(man), "",
"- Operator class (rules in `R/04b_operator_class.R`; every string and its class in `operator_classes_for_review.csv`):", "",
md_table(opc), "",
"## 2. Agency list", "",
sprintf("- %s local agencies in the table: %s municipal police, %s sheriffs, %s county police, %s unclear.",
        f(nrow(ags)), f(sum(ags$agency_type == "Municipal police")), f(sum(ags$agency_type == "Sheriff")),
        f(sum(ags$agency_type == "County police")), f(sum(ags$agency_type == "County (type unclear)"))),
sprintf("- %s are **historical** records (not in the current FBI directory; last employee report before 2024). They stay in `agencies.csv`, flagged, but get no cameras and are excluded from the statistics below. %s current agencies remain.",
        f(sum(ags$record_status == "historical")), f(nrow(cur))),
sprintf("- Geography: %s current agencies have a usable place or county code; %s do not (`geo_status`).",
        f(sum(cur$geo_status %in% c("place_code_resolved", "county_code_resolved", "countywide_only"))),
        f(sum(!cur$geo_status %in% c("place_code_resolved", "county_code_resolved", "countywide_only")))), "",
"## 3. How cameras were placed (located measure)", "",
md_table(bst), "",
"- `direct_*_name_mismatch`: the PD's LEAIC code points to a Census entity with a different name. Mostly spelling (Middleboro/Middleborough) or consolidated governments (Metro Nashville, Lexington-Fayette); listed in `method_b_pd_code_name_mismatches.csv` for review.",
"- `inferred_*`: assignment by rule, not verified (city with no PD in the list -> county agency; consolidated government or county with no county agency -> county-wide PD).",
"- `unresolved_shared_code`: two PDs share a code and the name does not decide it; left unassigned.",
"- `no_local_agency`: state-police areas (DE, PA, New England); correctly not assigned.", "",
"Attribution basis:", "", md_table(att), "",
"Agencies with zero located cameras, by reason:", "", md_table(zero), "",
"## 4. Cameras per agency", "",
"### Located (current agencies)", "",
md_table(tab("located", SETS, c("overall", "agency_type"))), "",
md_table(tab("located", SETS, "population_bin")), "",
"### Attributed", "",
md_table(tab("attributed", SETS, c("overall", "agency_type"))), "",
"### Tagged", "",
md_table(tab("tagged", SETS, c("overall", "agency_type"))), "",
"Per-capita columns in `agencies.csv` use FBI population served. That population is not guaranteed to match the area the located measure uses (e.g., a sheriff's population is usually the unincorporated area only, while inferred rules can add contract cities).", "",
"## 5. Historical comparison with agency-reported Flock counts", "",
"N&O \"Private Eyes\" data, scraped from Flock transparency portals on 2024-04-26, vs. Flock-manufacturer cameras in OSM on the pull date (2.5 years later). This shows whether the measures rank agencies sensibly. It does **not** establish current per-agency accuracy: growth, removals, mapping gaps and attribution errors all move the ratio, and the portal sample is not representative (no county police; few sheriffs).", "",
md_table(vt, 2), "",
"Located measure by group:", "", md_table(vgt, 2), "",
"Largest disagreements are in `validation_largest_residuals.csv` (e.g., San Diego PD: 528 reported vs 85 located; Puyallup WA PD: 2 vs 42). Plot: `validation_scatter.png`.", "",
"## 6. Limits", "",
sprintf("- **Ownership is mostly unknown.** %s of cameras have no operator tag. The located and attributed measures put them with the local agency by location; some belong to HOAs, businesses, other agencies or vendors.", pct(mean(cams$op_class == "missing"))),
"- **Access is not measured.** Shared networks let agencies search cameras outside their area; nothing here counts that.",
"- **Overlapping jurisdictions.** County, state, transit and university police operate inside cities. Cameras tagged to them are excluded from the city's located count, but untagged ones are not.",
"- **Uneven volunteer coverage.** A zero means none mapped (or no usable geography; see `located_zero_type`), not none installed.",
"- **Age of LEAIC (2012).** Place codes are old; new PDs are matched by name; mismatched codes are flagged.",
"- **Population served** comes from FBI records (2020-2025); 761 agencies lack it.",
"- **Mobile (car-mounted) ALPRs** are not in OSM.",
"- **Court comparisons.** `density_cameras_per_agency_court_cutoff.png` shows camera counts from two court cases for reference only; those networks are defined differently (see the caption and `court_cases.md`).",
"- No leaked or non-public Flock data were used."
)
writeLines(out, file.path(OUT, "summary.md"))
message("Wrote output/summary.md")
