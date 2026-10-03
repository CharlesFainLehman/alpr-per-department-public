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
mf   <- read_csv(file.path(OUT, "osm_counts_by_manufacturer.csv"), show_col_types = FALSE)
pull_date <- readLines(file.path(PROC, "osm_pull_date.txt"))
ql <- read_csv(list.files(file.path(RAW, "osm", pull_date), "query_log.csv", full.names = TRUE), show_col_types = FALSE)

n <- nrow(cams)
fam <- function(rx) sum(mf$n[str_detect(str_to_lower(mf$manufacturer), rx)])
man <- tibble(manufacturer = c("Flock", "Motorola / Vigilant", "Genetec", "Axis", "Leonardo / ELSAG", "Rekor", "Axon",
                               "PlateSmart", "(no manufacturer tag)"),
              rx = c("flock", "motorola|vigilant", "genetec", "axis", "leonardo|elsag", "rekor", "axon", "platesmart", "^\\(none\\)$")) |>
  mutate(cameras = map_int(rx, fam), share = pct(cameras / n)) |> select(-rx)
tagged <- sum(!is.na(cams$operator) & str_squish(cams$operator) != "")

a_basis <- cams |> count(a_basis) |> arrange(desc(n))
b_level <- cams |> count(b_level) |> arrange(desc(n))
cmp <- cams |> count(a_b_compare) |> arrange(desc(n))

stat_cols <- c("agencies", "cameras", "mean", "median", "p10", "p25", "p75", "p90", "p99", "max")
BIN_ORDER <- c("all", "Municipal police", "Sheriff", "County police", "County (type unclear)",
               "<2.5k", "2.5k-10k", "10k-25k", "25k-50k", "50k-100k", "100k-250k", "250k+", "unknown")
tab <- function(m, gv) st |> filter(method == m, group_var == gv) |>
  select(set, group, all_of(stat_cols)) |> arrange(set, match(group, BIN_ORDER))

vt <- vm |> transmute(method, n, pearson_r, spearman_rho, pearson_r_log1p,
                      median_ratio = median_ratio_osm_over_reported, median_abs_error,
                      share_osm_zero, share_osm_above_reported)
v <- read_csv(file.path(OUT, "validation_comparison.csv"), show_col_types = FALSE)
va <- v |> filter(osm_a > 0, reported > 0)
vmatch <- read_csv(file.path(OUT, "validation_agency_matches.csv"), show_col_types = FALSE)

excl <- readRDS(file.path(PROC, "method_b.rds")) |> filter(b_excluded)
nopd <- sum(cams$b_level == "place_without_pd_to_county", na.rm = TRUE)
nm <- read_csv(file.path(OUT, "method_b_pd_place_name_matches.csv"), show_col_types = FALSE)
cw <- cams |> filter(b_level %in% c("consolidated_countywide_pd", "countywide_pd_no_county_agency"))
fz <- read_csv(file.path(OUT, "method_a_fuzzy_matches_for_review.csv"), show_col_types = FALSE)
ag_noleaic <- sum(is.na(readRDS(file.path(PROC, "agencies.rds"))$leaic_name))

out <- c(
"# ALPRs per US police agency: summary", "",
sprintf("OSM pull: %s (Overpass; OSM base timestamps %s to %s). Agencies: FBI CDE directory + FBI employee file (population served, latest year per ORI) + BJS LEAIC 2012. Boundaries: TIGER/Line %d. Population: ACS 2020-2024 5-year.",
        pull_date, min(ql$osm_base), max(ql$osm_base), TIGER_YEAR), "",
"## 1. Camera data", "",
sprintf("- US ALPR nodes (`man_made=surveillance` + `surveillance:type=ALPR`), inside the 50 states + DC: **%s**", f(n)),
sprintf("- With a non-empty `operator` tag: **%s (%s)**", f(tagged), pct(tagged / n)),
"- By manufacturer (spelling variants grouped; full list in `osm_counts_by_manufacturer.csv`):", "",
md_table(man), "",
"## 2. Agency list", "",
sprintf("- %s local agencies: %s municipal police, %s sheriffs, %s county police, %s county agencies of unclear type.",
        f(nrow(ags)), f(sum(ags$agency_type == "Municipal police")), f(sum(ags$agency_type == "Sheriff")),
        f(sum(ags$agency_type == "County police")), f(sum(ags$agency_type == "County (type unclear)"))),
sprintf("- %s agencies have no LEAIC record (ORI created or changed after 2012). %s have no FBI population.",
        f(ag_noleaic), f(sum(is.na(ags$population_fbi)))), "",
"## 3. Crosswalk", "",
"### Method A: operator tag", "",
md_table(a_basis |> mutate(a_basis = coalesce(a_basis, "(no operator tag, or unmatched)"))), "",
sprintf("- Fuzzy: %d candidates written to `method_a_fuzzy_matches_for_review.csv`; %d accepted (all spelling typos). Never across states.",
        nrow(fz), sum(fz$accepted)),
"- `jurisdiction_only` = operator names a city or county without an agency word (\"City of Beverly Hills\"); assigned to that jurisdiction's PD or sheriff. Review these.", "",
"### Method B: spatial join", "",
md_table(b_level), "",
sprintf("- Excluded as private: **%s cameras** (surveillance=private: %s; operator:type private/business/university etc.: %s; operator name looks private (retailer, mall, HOA, school, hospital...): %s). Overlapping flags counted once in the total.",
        f(nrow(excl)), f(sum(excl$excl_surveillance_private)), f(sum(excl$excl_operator_type)), f(sum(excl$excl_operator_text))),
sprintf("- `place_without_pd_to_county` (%s cameras): inside a city with no PD in the agency list (mostly contract cities); assigned to the sheriff.", f(nopd)),
sprintf("- `county_subdivision`: town/township police in New England, NJ, PA, MI, NY, OH etc. (towns that are not Census places). Not in the original spec; without it these cameras would go to the sheriff."),
sprintf("- County-wide municipal PDs (%s cameras): Louisville Metro, Athens-Clarke (consolidated governments), Charlotte-Mecklenburg, Las Vegas Metro, Metro Nashville, Honolulu, Los Alamos, Indianapolis (counties with no sheriff/county-police record).", f(nrow(cw))),
sprintf("- %d PDs had no usable LEAIC place code and were linked to a %d Census place by exact unique name (`method_b_pd_place_name_matches.csv`).", nrow(nm), TIGER_YEAR),
"- `unassigned`: areas policed by state police (DE, PA, CT, MA, RI, VT). Correctly not assigned to a local agency.", "",
"### A vs. B", "",
md_table(cmp), "",
"Disagreements are mostly county agencies operating cameras inside city limits (e.g., St. Charles County PD inside St. Charles and O'Fallon, MO) and cities placing cameras just past their borders. Method B gives those to the city.", "",
"## 4. Cameras per agency", "",
"### Method B (spatial join; the main estimate)", "",
"Overall and by agency type:", "",
md_table(bind_rows(tab("B", "overall"), tab("B", "agency_type"))), "",
"By population served (FBI):", "",
md_table(tab("B", "population_bin")), "",
"### Method A (operator tag; a floor, not an estimate)", "",
md_table(bind_rows(tab("A", "overall"), tab("A", "agency_type"))), "",
md_table(tab("A", "population_bin")), "",
"Cameras per 10,000 residents are in `agencies.csv` (`per10k_a`, `per10k_b`), using FBI population served. A sheriff's FBI population is usually only the unincorporated area, so method B counts for sheriffs are per that area.", "",
"## 5. Validation (N&O \"Private Eyes\", Flock transparency portals, 2024-04-26)", "",
sprintf("- %d rows after dropping Flock/Training/DNU rows and rows with no camera count; %d matched to the agency list (unmatched are mostly universities, airports, DAs, tribal PDs).",
        nrow(vmatch), nrow(v)),
"- Compared with OSM **Flock-manufacturer** cameras assigned to the agency.", "",
md_table(vt, 2), "",
sprintf("- Method A among the %d agencies where it finds at least one camera: median ratio %.2f, r(log) %.2f.",
        nrow(va), median(va$osm_a / va$reported), cor(log1p(va$osm_a), log1p(va$reported))),
"- OSM data are 2.5 years newer than the portal counts, so OSM counts above the 2024 figure are expected (method B: median ratio above 1). Method B also counts Flock cameras owned by other public bodies inside the city (e.g., county agencies, DOTs), which pushes it up; method A misses every untagged camera, which pushes it to zero for most agencies.",
"- Plot: `validation_scatter.png`.", "",
"## 6. Limits of the data", "",
sprintf("- **Untagged operators.** Only %s of cameras have an operator tag, so method A is a floor. Method B infers the owner from location.", pct(tagged / n)),
"- **Private cameras inside city limits.** Method B excludes only cameras tagged private or with an obviously private operator name. Untagged private cameras (HOAs, businesses, which Flock sells to heavily) are assigned to the local PD. Flock as `operator` (a vendor, not an owner) is not excluded.",
"- **Overlapping jurisdictions.** Cameras run by sheriffs, county police, state police, DOTs, transit and university police inside a city are assigned to the city PD by method B. Where >1 PD or >1 county agency shares a code, the one with the largest FBI population gets the cameras (`method_b_places_with_multiple_pds.csv`, `method_b_counties_with_multiple_county_agencies.csv`).",
"- **Uneven volunteer coverage.** DeFlock/OSM mapping is crowdsourced. Zero cameras means none mapped, not none installed. Coverage is denser where active mappers live; cross-agency comparisons reflect mapping effort as well as deployment.",
sprintf("- **Age of LEAIC.** LEAIC is from 2012. %s agencies have no LEAIC record; place codes for consolidated governments changed since (handled by the county-wide rule); new cities and new PDs are matched by name (%d) or fall to the sheriff.", f(ag_noleaic), nrow(nm)),
"- **Population served.** FBI figures (latest year 2020-2025). Missing for some agencies; per-capita values are NA there. Sheriffs with zero FBI population (no patrol area) have NA per-capita rates.",
"- **Contract cities.** California contract cities (ORIs ending in X, e.g., Mission Viejo PD) are separate FBI agencies served by the sheriff; method B gives them their own cameras.",
"- **Mobile ALPRs** (car-mounted) are not in OSM; these counts are fixed cameras only.",
"- No leaked or non-public Flock data were used."
)
writeLines(out, file.path(OUT, "summary.md"))
message("Wrote output/summary.md")
