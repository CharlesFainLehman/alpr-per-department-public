# Match each camera's OSM operator tag to an agency name in the same state ("Austin Police Department",
# "City of Hollywood", "Pasco Sheriff's Office"). 05_classify_operators.R uses the result to tell local-agency
# cameras from DOT, university, retailer and other cameras, so those can be excluded in 06_locate_cameras.R.
#
# Steps (on unique state + operator strings, then joined back to cameras):
#   1. Normalize text; detect agency kind (police / sheriff / none) and the jurisdiction "core".
#   2. Exact match on (state, kind, core).
#   3. Exact match on (state, kind, core with "city/town/township/village/borough" dropped), if unique.
#   4. Operators with no kind word ("City of X", "County of Y", bare place name): match the
#      jurisdiction to its municipal PD or sheriff. Flagged as basis = "jurisdiction_only".
#   5. Fuzzy (Jaro-Winkler) on core within state and kind. Accepted only if distance <= FUZZY_MAX and
#      the runner-up is at least FUZZY_GAP worse. Every fuzzy candidate is written for review.
#   Never across states.
source("R/00_setup.R")
library(stringdist)

FUZZY_MAX <- 0.05
FUZZY_GAP <- 0.05

cams <- readRDS(file.path(PROC, "osm_alpr.rds"))
ag   <- readRDS(file.path(PROC, "agencies.rds")) |> filter(is_current(record_status))
n_log(cams, "cameras in"); n_log(ag, "agencies in")

source("R/name_parser.R")

# Agency side: kind from FBI type, not from the name.
ag_p <- bind_cols(ag |> select(ori, name, state, agency_type), parse_name(ag$name)) |>
  mutate(kind = if_else(agency_type == "Sheriff", "sheriff", "police"),
         is_county = agency_type != "Municipal police",
         core2 = if_else(is_county, core, core2))   # keep "county" etc. for county agencies

uniq_key <- function(df, key) df |> filter(.data[[key]] != "") |> group_by(state, kind, .data[[key]]) |>
  summarise(n_ag = n(), ori = first(ori), .groups = "drop") |> rename(k = all_of(key))
k1 <- uniq_key(ag_p, "core"); k2 <- uniq_key(ag_p, "core2")

# Operator side -------------------------------------------------------------------------------------
ops <- cams |> filter(!is.na(operator), str_squish(operator) != "") |> count(state, operator, name = "n_cameras")
n_log(ops, "unique (state, operator) strings")
ops <- bind_cols(ops, parse_name(ops$operator))
# Drop the camera's own state name/abbreviation at the end of the core ("Bristol TN PD", "Troy PD (Michigan)").
st_rx <- paste0("\\s(", str_to_lower(ops$state), "|", str_to_lower(STATES$name[match(ops$state, STATES$abbr)]), ")$")
ops <- ops |> mutate(core = str_squish(str_remove(core, st_rx)), core2 = str_squish(str_remove(core2, st_rx)))

# Step 2: exact on core ("Town of X" first tries the typed core "x town")
ops <- ops |> left_join(k1 |> filter(n_ag == 1) |> select(state, kind, k, ori_typed = ori), by = c("state", "kind", "core_typed" = "k"))
muni_typed <- ag_p |> filter(!is_county, core != "") |> add_count(state, core, name = "n_t") |> filter(n_t == 1) |>
  select(state, core, ori_t2 = ori)
ops <- ops |> left_join(muni_typed, by = c("state", "core_typed" = "core")) |>
  mutate(ori_typed = coalesce(ori_typed, if_else(kind == "none", NA, ori_t2))) |> select(-ori_t2)
message("  operators matched on typed core (Town/Township/Village of X): ", sum(!is.na(ops$ori_typed)))
m <- ops |> left_join(k1, by = c("state", "kind", "core" = "k"))
n_log(m, "operators after exact join (core)")
m <- m |> mutate(operator_ori = case_when(!is.na(ori_typed) ~ ori_typed, n_ag == 1 ~ ori, TRUE ~ NA),
                 operator_match = case_when(!is.na(ori_typed) ~ "exact_typed", n_ag == 1 ~ "exact", TRUE ~ NA),
                 ambiguous = is.na(ori_typed) & !is.na(n_ag) & n_ag > 1) |> select(-ori, -n_ag, -ori_typed)
message("  exact (core): ", sum(!is.na(m$operator_ori)), "; ambiguous: ", sum(m$ambiguous))

# Step 3: exact on core2
m <- m |> left_join(k2, by = c("state", "kind", "core2" = "k"))
n_log(m, "operators after exact join (core2)")
m <- m |> mutate(take = is.na(operator_ori) & !is.na(n_ag) & n_ag == 1 & kind != "none",
                 operator_match = if_else(take, "exact_no_muni_word", operator_match),
                 operator_ori = if_else(take, ori, operator_ori),
                 ambiguous = ambiguous | (is.na(operator_ori) & !is.na(n_ag) & n_ag > 1)) |>
  select(-ori, -n_ag, -take)
message("  + exact (core2): ", sum(m$operator_match == "exact_no_muni_word", na.rm = TRUE))

# Step 3b: county word omitted ("Pasco Sheriff's Office" -> Pasco County Sheriff's Office)
m <- m |> mutate(core_cty = if_else(is.na(operator_ori) & kind != "none" & !str_detect(core2, "\\b(county|parish)\\b"),
                                    paste(core2, "county"), NA)) |>
  left_join(k2 |> filter(n_ag == 1) |> select(state, kind, k, ori_c = ori), by = c("state", "kind", "core_cty" = "k"))
n_log(m, "operators after exact join (county word added)")
m <- m |> mutate(operator_match = if_else(is.na(operator_ori) & !is.na(ori_c), "exact_county_added", operator_match),
                 operator_ori = coalesce(operator_ori, ori_c)) |> select(-ori_c, -core_cty)
message("  + exact (county word added): ", sum(m$operator_match == "exact_county_added", na.rm = TRUE))

# Step 4: jurisdiction only ("City of X", "County of Y", "X County", bare "X")
juris <- m |> filter(is.na(operator_ori), kind == "none") |>
  mutate(target_kind = if_else(prefix == "county", "sheriff", "police"),
         target_core = if_else(prefix == "county", str_replace(core, "^(.*?)( county| parish)?$", "\\1 county"), core2))
ag_j <- ag_p |> mutate(jk = if_else(is_county, "sheriff", "police"),
                       jcore = if_else(is_county, str_replace(core, "^(.*?)( county| parish)?$", "\\1 county"), core2)) |>
  group_by(state, jk, jcore) |> summarise(n_ag = n(), ori_j = first(ori), .groups = "drop")
juris <- juris |> left_join(ag_j, by = c("state", "target_kind" = "jk", "target_core" = "jcore")) |>
  filter(n_ag == 1) |> select(state, operator, ori_j)
m <- m |> left_join(juris, by = c("state", "operator")) |>
  mutate(operator_match = if_else(is.na(operator_ori) & !is.na(ori_j), "jurisdiction_only", operator_match),
         operator_ori = coalesce(operator_ori, ori_j)) |> select(-ori_j)
message("  + jurisdiction only: ", sum(m$operator_match == "jurisdiction_only", na.rm = TRUE))

# Step 5: fuzzy within state and kind (police/sheriff operators only)
fz <- m |> filter(is.na(operator_ori), kind != "none", core2 != "")
fuzzy <- pmap_dfr(fz |> select(state, operator, kind, core2, n_cameras), \(state, operator, kind, core2, n_cameras) {
  cand <- ag_p[ag_p$state == state & ag_p$kind == kind, ]
  if (!nrow(cand)) return(NULL)
  d <- stringdist(core2, cand$core2, method = "jw", p = 0.1)
  o <- order(d)
  tibble(state = state, operator = operator, n_cameras = n_cameras, op_core = core2,
         best_ori = cand$ori[o[1]], best_name = cand$name[o[1]], best_dist = d[o[1]],
         second_name = if (length(o) > 1) cand$name[o[2]] else NA, second_dist = if (length(o) > 1) d[o[2]] else NA)
})
# Last word must also agree (blocks "Virginia Tech" -> "Virginia Beach").
last_tok <- function(x) str_extract(x, "\\S+$")
fuzzy <- fuzzy |> left_join(ag_p |> select(best_ori = ori, best_core2 = core2), by = "best_ori") |>
  mutate(last_word_dist = stringdist(last_tok(op_core), last_tok(best_core2), method = "jw", p = 0.1),
         accepted = best_dist <= FUZZY_MAX & (is.na(second_dist) | second_dist - best_dist >= FUZZY_GAP) &
                    last_word_dist <= 0.1) |>
  arrange(desc(accepted), best_dist)
write_csv(fuzzy |> filter(best_dist <= 0.15), file.path(REVIEW, "operator_fuzzy_matches_for_review.csv"))
message("  fuzzy candidates (dist <= 0.15) written for review: ", sum(fuzzy$best_dist <= 0.15),
        "; accepted: ", sum(fuzzy$accepted))
m <- m |> left_join(fuzzy |> filter(accepted) |> select(state, operator, f_ori = best_ori, f_dist = best_dist),
                    by = c("state", "operator")) |>
  mutate(operator_match = if_else(is.na(operator_ori) & !is.na(f_ori), "fuzzy", operator_match), operator_ori = coalesce(operator_ori, f_ori)) |>
  select(-f_ori)

# Results ------------------------------------------------------------------------------------------
m <- m |> left_join(ag |> select(operator_ori = ori, matched_name = name, matched_type = agency_type), by = "operator_ori")
write_csv(m |> arrange(state, desc(n_cameras)), file.path(REVIEW, "operator_crosswalk.csv"))
message("\nOperator match summary (unique state+operator strings / cameras):")
print(m |> mutate(operator_match = coalesce(operator_match, if_else(ambiguous, "unmatched_ambiguous", "unmatched"))) |>
        group_by(operator_match) |> summarise(strings = n(), cameras = sum(n_cameras)) |> arrange(desc(cameras)))

cams_a <- cams |> select(osm_id, state, operator) |>
  left_join(m |> select(state, operator, operator_ori, operator_match), by = c("state", "operator"))
n_log(cams_a, "cameras after joining the operator matches")
stopifnot(nrow(cams_a) == nrow(cams))
saveRDS(cams_a |> select(osm_id, operator_ori, operator_match), file.path(PROC, "operator_match.rds"))
