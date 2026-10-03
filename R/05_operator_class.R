# Classify every camera's operator into one category, used by method B and the attribution measure.
#
#   missing          no operator tag
#   vendor           the camera maker / vendor is named, not the owner (e.g., "Flock Safety")
#   local_police     operator matched to a local PD or sheriff by method A
#   local_government a city/county named without an agency word, matched by method A ("City of Beverly Hills")
#   police_unmatched police/sheriff-like name not matched to the agency list
#   public_other     public body outside the local-agency scope: DOTs, transit, toll, ports, airports,
#                    state police / highway patrol, federal agencies, universities, colleges, schools,
#                    district attorneys, housing authorities
#   private          retailers, malls, HOAs, businesses, hospitals, churches, private security,
#                    plus surveillance=private or operator:type private/business
#   unclassified     anything else (reviewed list: output/review/operator_classes_for_review.csv)
#
# Order matters: vendor/placeholder first, then a method-A match to a local agency (so "University
# Heights PD" or "North College Hill PD" is not caught by "university"/"college"), then the
# public-other and private patterns. R/operator_class_overrides.csv holds reviewed exceptions.
source("R/00_setup.R")

cams <- readRDS(file.path(PROC, "osm_alpr.rds"))
a    <- readRDS(file.path(PROC, "method_a.rds"))
ovr  <- read_csv("R/operator_class_overrides.csv", col_types = cols(.default = "c"))
n_log(cams, "cameras in")

x <- cams |> select(osm_id, state, operator, operator_type, surveillance) |>
  left_join(a, by = "osm_id") |>
  mutate(op = str_squish(operator), op_l = str_to_lower(coalesce(op, "")))
n_log(x, "cameras after joining method A")

VENDOR_RX  <- "^(the )?(flock|flock safety|flock group( inc\\.?)?|flock_safety|motorola( solutions)?|vigilant( solutions)?|rekor|genetec|leonardo|elsag|axon|ubicquia)$"
GENERIC_PRIVATE_RX <- "^\\[?(private|hoa|land ?owner|owner|business|residential|commercial|gated community)\\]?$"
GENERIC_UNKNOWN_RX <- "^(unknown|police|law enforcement|government|city|county|n/?a|none)$"
PUBLIC_OTHER_RX <- paste0(
  "department of transportation|\\bdot\\b|d\\.o\\.t|\\bdpw\\b|transportation authority|transit|\\bm\\.?t\\.?a\\b|",
  "metropolitan transportation|bridges and tunnels|turnpike|thruway|toll|tollway|port authority|port of authority|panynj|",
  "airport|aviation|highway patrol|\\bchp\\b|state police|state patrol|state trooper|department of public safety \\(state\\)|",
  "texas department of public safety|wisdot|customs|border patrol|border protection|\\bcbp\\b|drug enforcement|\\bdea\\b|",
  "\\bfbi\\b|federal|national park|park service|veterans affairs|air force|\\bnavy\\b|\\barmy\\b|military|",
  "university|college|\\bschools?\\b|school district|\\bisd\\b|academy|district attorney|\\bda'?s office|",
  "housing authority|housing commission|state of |department of corrections|state parks|cal fire|",
  "forest preserve|metro parks|park district|regional transportation|transportation corridor|bay area toll|",
  "golden gate bridge|redevelopment|municipal utility district|community development district|improvement district|",
  "tribal|nation\\b|indian police|pueblo|\\bbyu\\b|\\bunc\\b|virginia tech|\\bnau\\b|\\buc [a-z]+ police|",
  "community coll|capitol police|\\buttyler\\b|wsdot|dept\\.? of corrections|task force")
PRIVATE_RX <- paste0(
  "lowe'?s|home depot|walmart|wal-mart|\\btarget\\b|kroger|meijer|dierbergs|costco|sam'?s club|bj'?s|wegmans|",
  "simon property|\\bmall\\b|plaza|town cent(er|re)|towne cent|galleria|outlets?\\b|shopping|marketplace|",
  "casino|resort|hotel|\\binn\\b|lodge|apartments?|homeowners?|home owners|\\bhoa\\b|owners association|",
  "\\bassociation\\b|\\bpoa\\b|\\broa\\b|condominium|properties|property|real estate|realty|\\bllc\\b|\\binc\\.?\\b|",
  "\\bcorp(oration)?\\b|\\bcompany\\b|\\bco\\.$|group\\b|bank\\b|credit union|insurance|mortgage|",
  "health|hospital|medical|kaiser|clinic|promedica|adventhealth|wakemed|church|latter.day|",
  "auto wash|car wash|fedex|\\bups\\b|\\bdhl\\b|amazon|boeing|general motors|dte energy|",
  "wholesale|markets?\\b|foods?\\b|quiktrip|buc.?ee|\\bcvs\\b|walgreens|sporting|sports|bowlero|",
  "parking|security\\b|storage|stadium|arena|great wolf|camp |jellystone|pultegroup|homes\\b|communities|",
  "estates|subdivision|neighborhood|hills homeowners|landlord|ranch\\b|safeway|scheels|fred meyer|",
  "home depo\\b|management\\b|destiny usa|park meadows|towne square")
POLICE_RX <- "police|sher+if+|serrif|\\bpd\\b|\\bso\\b|public safety|marshal|constable"

x <- x |> left_join(ovr |> select(op = operator, ovr_class = op_class), by = "op") |>
  mutate(
    op_class = case_when(
      !is.na(ovr_class) ~ ovr_class,
      coalesce(str_to_lower(surveillance) == "private", FALSE) & is.na(a_ori) & !str_detect(op_l, POLICE_RX) ~ "private",
      op_l == "" ~ "missing",
      str_detect(op_l, VENDOR_RX) ~ "vendor",
      str_detect(op_l, GENERIC_PRIVATE_RX) ~ "private",
      str_detect(op_l, GENERIC_UNKNOWN_RX) ~ "unclassified",
      !is.na(a_ori) & a_basis == "jurisdiction_only" ~ "local_government",
      !is.na(a_ori) ~ "local_police",
      str_detect(op_l, PUBLIC_OTHER_RX) ~ "public_other",
      str_detect(op_l, PRIVATE_RX) ~ "private",
      str_to_lower(operator_type) %in% c("private", "business", "commercial") ~ "private",
      str_detect(op_l, POLICE_RX) ~ "police_unmatched",
      TRUE ~ "unclassified"),
    op_class_source = if_else(!is.na(ovr_class), "override", "rule"))
n_log(x, "cameras classified")
print(count(x, op_class, sort = TRUE))

# Review file: every distinct operator string with its class
rev <- x |> filter(op_l != "") |> count(op_class, operator, sort = TRUE)
write_csv(rev, file.path(REVIEW, "operator_classes_for_review.csv"))
saveRDS(x |> select(osm_id, op_class, op_class_source), file.path(PROC, "operator_class.rds"))
