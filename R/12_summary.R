# Write output/summary.md from the saved outputs. Every number in the text is computed here.
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
rd <- \(name, ...) read_csv(file.path(OUT, name), show_col_types = FALSE, ...)

cams <- rd("cameras.csv.gz", col_types = cols(.default = "c"))
ags  <- rd("agencies.csv")
st   <- rd("summary_stats.csv")
vm   <- rd("validation_metrics.csv")
vg   <- rd("validation_metrics_by_group.csv")
resid <- rd("validation_largest_residuals.csv")
wv   <- rd("validation_web_comparison.csv", col_types = cols(.default = "c")) |> mutate(across(c(reported, osm_located), as.numeric))
wsize <- rd("validation_web_density_by_size.csv")
mn   <- rd("validation_mn_bca_comparison.csv")
mf   <- rd("osm_counts_by_manufacturer.csv")
pull_date <- readLines(file.path(PROC, "osm_pull_date.txt"))
ql <- read_csv(file.path(RAW, "osm", pull_date, "query_log.csv"), show_col_types = FALSE)
cur <- ags |> filter(record_status != "historical")
USABLE <- c("place_code_resolved", "county_code_resolved", "countywide_only")

n <- nrow(cams)
# manufacturer families; a string naming two makers ("Flock Safety;Motorola Solutions") counts under the first listed
FAM <- c("Flock" = "flock", "Motorola / Vigilant" = "motorola|vigilant", "Genetec" = "genetec", "Axis" = "axis",
         "Leonardo / ELSAG" = "leonardo|elsag", "Rekor" = "rekor", "Axon" = "axon", "PlateSmart" = "platesmart",
         "(no manufacturer tag)" = "^\\(none\\)$")
fam_of <- function(s) { s <- str_to_lower(s); hit <- map_int(s, \(z) { k <- which(map_lgl(FAM, \(rx) str_detect(z, rx)))
  if (length(k)) min(k) else NA_integer_ }); names(FAM)[hit] }
man <- mf |> mutate(family = fam_of(manufacturer)) |> filter(!is.na(family)) |> count(family, wt = n, name = "cameras") |>
  arrange(match(family, names(FAM))) |> mutate(share = pct(cameras / n)) |> rename(manufacturer = family)
tagged_op <- sum(!is.na(cams$operator) & cams$operator != "")

opc <- cams |> count(operator_class = op_class, name = "cameras") |> arrange(desc(cameras)) |> mutate(share = pct(cameras / n))
bst <- cams |> count(b_status, name = "cameras") |> arrange(desc(cameras))
zero <- ags |> filter(cameras_located == 0) |> count(reason = located_zero_type, name = "agencies") |> arrange(desc(agencies))

stat_cols <- c("agencies", "cameras", "mean", "median", "p10", "p25", "p75", "p90", "p99", "max")
BIN_ORDER <- c("all", "Municipal police", "Sheriff", "County police", "County (type unclear)",
               "<2.5k", "2.5k-10k", "10k-25k", "25k-50k", "50k-100k", "100k-250k", "250k+", "unknown")
tab <- function(m, sets, gv) st |> filter(measure == m, set %in% sets, group_var %in% gv) |>
  select(set, group, all_of(stat_cols)) |> arrange(set, match(group, BIN_ORDER))
SETS <- c("agencies with >=1 camera", "agencies with usable geography")
measure_overall <- bind_rows(lapply(c("located", "attributed", "tagged"), \(m)
  tab(m, SETS[1], "overall") |> mutate(measure = m, .before = 1) |> select(-set, -group)))

vt <- vm |> transmute(measure, n, r_log = pearson_r_log1p, spearman = spearman_rho,
                      median_ratio = median_ratio_osm_over_reported, within_2x = share_within_factor_2,
                      below_half = share_below_half, above_double = share_above_double, osm_zero = share_osm_zero,
                      median_abs_error)
vgt <- vg |> filter(group_var == "agency_type") |>
  transmute(group, n, median_ratio = median_ratio_osm_over_reported, within_2x = share_within_factor_2, r_log = pearson_r_log1p)
gap_years <- round(as.numeric(as.Date(pull_date) - as.Date("2024-04-26")) / 365.25, 1)
ex_lo <- resid |> filter(ratio_located < 1) |> slice(1); ex_hi <- resid |> filter(ratio_located > 1) |> slice(1)   # file is sorted by |log residual|

core <- wv |> filter(program_status == "current", mobile_flag == "no")
yy <- substr(wv$as_of_date, 1, 4)
zero_rep <- core |> filter(reported == 0) |> arrange(desc(osm_located))
r250 <- wsize$median_ratio_osm_to_reported[wsize$size == "250k+"]
wmet <- rd("validation_web_metrics.csv") |> filter(!(measure == "attributed")) |>
  transmute(subset, n, r_log = pearson_r_log1p, median_ratio, within_2x, below_half, above_double)
mn_local <- mn |> filter(!non_local)
mn_zero <- mn_local |> filter(!withheld, !is.na(ori), listed_locations == 0) |> arrange(desc(osm_located))

out <- c(
"# Mapped ALPRs per US local police agency: summary", "",
sprintf("OSM pull %s (Overpass; OSM base timestamps %s to %s). Agencies: FBI CDE directory + FBI employee file (population served) + BJS LEAIC 2012. Boundaries: TIGER/Line %d. Population: ACS %d-%d 5-year.",
        pull_date, min(ql$osm_base), max(ql$osm_base), TIGER_YEAR, ACS_YEAR - 4, ACS_YEAR), "",
"**What these numbers are.** Counts of license plate reader cameras *mapped* in OpenStreetMap (the crowdsourced layer DeFlock maintains), tied to local agencies three ways. None is a verified inventory of cameras an agency owns, and none measures what an agency can *search*: through shared networks (e.g., Flock sharing and national lookup) an agency can query cameras far outside its own area. Neither the tagged nor the located measure is a lower or upper bound: both omit some cameras and include some wrongly.", "",
"| Measure | Definition |", "| --- | --- |",
"| **Located** | Cameras inside the agency's area (incorporated place, town/township, or the county outside them), excluding cameras whose operator tag names a private party or another public body (DOT, transit, state police, federal, university, school). Includes cameras with no operator tag. |",
"| **Tagged** | Cameras whose `operator` tag names the agency (name match within the state). |",
"| **Attributed** | Tagged cameras, plus cameras with no operator, a vendor-only tag (\"Flock Safety\"), or an unmatched police tag that are located in the agency's area (inferred). |", "",
"## 1. Camera data", "",
sprintf("- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), 50 states + DC: **%s**. %s rows share exact coordinates with another node (possible duplicates or multi-direction installs; flagged `n_same_coords`, not removed).", f(n), f(sum(as.integer(cams$n_same_coords) > 1))),
sprintf("- With an `operator` tag: **%s (%s)**.", f(tagged_op), pct(tagged_op / n)),
"- By manufacturer (spelling variants grouped; full list `osm_counts_by_manufacturer.csv`):", "",
md_table(man), "",
"- Operator class (rules in `R/05_operator_class.R`; every string and its class in `review/operator_classes_for_review.csv`):", "",
md_table(opc), "",
"## 2. Agency list", "",
sprintf("- %s local agencies in the table: %s municipal police, %s sheriffs, %s county police, %s unclear.",
        f(nrow(ags)), f(sum(ags$agency_type == "Municipal police")), f(sum(ags$agency_type == "Sheriff")),
        f(sum(ags$agency_type == "County police")), f(sum(ags$agency_type == "County (type unclear)"))),
sprintf("- %s are **historical** records (not in the current FBI directory; last employee report before 2024). They stay in `agencies.csv`, flagged, but get no cameras and are excluded from the statistics below. %s current agencies remain.",
        f(sum(ags$record_status == "historical")), f(nrow(cur))),
sprintf("- Geography: %s current agencies have a usable place or county code; %s do not (`geo_status`).",
        f(sum(cur$geo_status %in% USABLE)), f(sum(!cur$geo_status %in% USABLE))),
sprintf("- Population served comes from FBI records (%d-%d); %s agencies lack it.", min(ags$pop_year, na.rm = TRUE), max(ags$pop_year, na.rm = TRUE), f(sum(is.na(ags$population_fbi)))), "",
"## 3. How cameras were placed (located measure)", "",
md_table(bst), "",
"- `direct_*_name_mismatch`: the PD's LEAIC code points to a Census entity with a different name (spelling, consolidated governments, or a wrong code); listed in `review/method_b_pd_code_name_mismatches.csv`.",
"- `inferred_*`: assignment by rule, not verified (city with no PD in the list -> county agency; consolidated government or county with no county agency -> county-wide PD).",
"- `unresolved_shared_code`: two PDs share a code and the name does not decide it. `no_local_agency`: state-police areas.", "",
"Agencies with zero located cameras, by reason:", "", md_table(zero), "",
"## 4. Cameras per agency (current agencies)", "",
"Agencies with at least one camera under each measure:", "", md_table(measure_overall), "",
"Located measure by agency type and by population served (`summary_stats.csv` has the same split for the other measures):", "",
md_table(tab("located", SETS, c("overall", "agency_type"))), "",
md_table(tab("located", SETS[1], "population_bin") |> select(-set)), "",
"Per-capita columns in `agencies.csv` use FBI population served, which need not match the area the located measure uses (a sheriff's population is usually the unincorporated area only; inferred rules can add contract cities).", "",
"## 5. Historical comparison with agency-reported Flock counts", "",
sprintf("N&O \"Private Eyes\" data, scraped from Flock transparency portals on 2024-04-26, vs. Flock-manufacturer cameras in OSM on the pull date (%.1f years later). This shows whether the measures rank agencies sensibly. It does **not** establish current per-agency accuracy: growth, removals, mapping gaps and attribution errors all move the ratio, and the portal sample is not representative (%s).",
        gap_years, paste(sprintf("%d %s", vgt$n, str_to_lower(vgt$group)), collapse = ", ")), "",
md_table(vt, 2), "",
sprintf("Largest disagreements (located measure) are in `validation_largest_residuals.csv`, e.g. %s: %d reported vs %d located; %s: %d vs %d. Plot: `validation_scatter.png`.",
        ex_lo$agency, ex_lo$reported, ex_lo$osm_located, ex_hi$agency, ex_hi$reported, ex_hi$osm_located), "",
sprintf("## 5b. Comparison with publicly reported counts (web-collected; sources dated %s-%s)", min(yy, na.rm = TRUE), max(yy, na.rm = TRUE)), "",
"Collected from agency websites, government documents and news articles quoting officials (`data/validation_web/`, one row per agency with URL and quote). The Flock transparency portals themselves block automated access and were not used directly. Rows are flagged for discontinued programs, planned/contracted counts, counts of locations rather than cameras, and figures that include mobile or shared cameras; the core comparison uses only current programs with a fixed, agency-operated camera count. Attributed-measure results (not shown) are within 0.01 of the located ones.", "",
md_table(wmet, 2), "",
sprintf("Agencies that report owning **zero** fixed cameras (%d in the core set; e.g., %s) often have mapped cameras in their area run by other parties (HOAs, businesses, neighboring agencies). The located measure cannot tell those apart, which is the largest source of disagreement.",
        nrow(zero_rep), paste(sprintf("%s %d", head(zero_rep$agency_name, 2), head(zero_rep$osm_located, 2)), collapse = ", ")), "",
"### Reported counts as an independent estimate of camera density", "",
sprintf("For the core agencies, reported counts and OSM give a similar per-capita picture. The OSM count runs higher for the largest agencies (median ratio %.2f for 250k+), where the located measure also picks up untagged cameras of other operators. The web sample is not random: it contains only agencies with cameras whose count was published, so it cannot estimate how many agencies have none, and it leans toward larger and contested programs. Plots: `validation_web_scatter.png`, `hist_web_sample_reported_vs_osm.png`.", r250), "",
md_table(rd("validation_web_density.csv"), 1), "",
md_table(wsize |> arrange(match(size, c("<10k", "10k-50k", "50k-250k", "250k+"))), 2), "",
"## 5c. Minnesota BCA register of fixed LPR locations", "",
sprintf("Minnesota agencies must report to the state Bureau of Criminal Apprehension where their stationary LPRs are; the BCA publishes the list (`data/validation_web/mn_bca_fixed_lpr_locations.csv`). This is a separate check: the register counts **locations, not cameras** (one location can hold several readers, e.g. one per direction), so a ratio above 1 is expected even with complete mapping. Local agencies that withheld their locations (%d) and non-local agencies (%d: State Patrol, tribal, university and airport police) are left out. Compared with all-vendor OSM located counts. `median_ratio` and `within_2x` use only agencies listing at least one location; the zero-listing agencies change only the correlations.",
        sum(mn_local$withheld), sum(mn$non_local)), "",
md_table(rd("validation_mn_bca_metrics.csv") |>
  transmute(subset, n, n_listing_zero, r_log = pearson_r_log1p, spearman = spearman_rho, median_ratio, within_2x, below_half, above_double), 2), "",
sprintf("Of the %d agencies that list no fixed locations, %d have no mapped cameras in their area and %d have some (largest: %s). Those are either cameras of other operators or gaps in the register.",
        nrow(mn_zero), sum(mn_zero$osm_located == 0), sum(mn_zero$osm_located > 0),
        paste(sprintf("%s %d", head(mn_zero$agency_name, 2), head(mn_zero$osm_located, 2)), collapse = "; ")), "",
"## 6. Limits", "",
sprintf("- **Ownership is mostly unknown.** %s of cameras have no operator tag. The located and attributed measures put them with the local agency by location; some belong to HOAs, businesses, other agencies or vendors.", pct(mean(cams$op_class == "missing"))),
"- **Access is not measured.** Shared networks let agencies search cameras outside their area; nothing here counts that.",
"- **Overlapping jurisdictions.** County, state, transit and university police operate inside cities. Cameras tagged to them are excluded from the city's located count, but untagged ones are not.",
"- **Uneven volunteer coverage.** A zero means none mapped (or no usable geography; see `located_zero_type`), not none installed.",
"- **Age of LEAIC (2012).** Place codes are old; new PDs are matched by name; mismatched codes are flagged.",
"- **Mobile (car-mounted) ALPRs** are not in OSM.",
"- **Court comparisons.** Camera counts in court cases (`docs/court_cases.md`) describe differently defined networks and are not comparable to these counts.",
"- No leaked or non-public Flock data were used."
)
writeLines(out, file.path(OUT, "summary.md"))
message("Wrote output/summary.md")
