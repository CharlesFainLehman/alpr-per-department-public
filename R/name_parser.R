# Agency-name parser shared by 04 (operator tags), 06 (PD-to-place names) and 08 (reported counts).
# parse_name() returns the normalized string, the agency kind (police / sheriff / none) and the jurisdiction core.

basic <- function(x) {
  # accents are transliterated first ("Cañon" -> "canon"); everything else non-alphanumeric becomes a space
  x |> stringi::stri_trans_general("Latin-ASCII") |> str_to_lower() |> str_replace_all("[’`]", "'") |> str_replace_all("'s\\b", "s") |>
    str_replace_all("&", " and ") |> str_replace_all("\\bst\\.\\s", "saint ") |>
    str_replace(",[^,]* (county|parish)$", "") |>          # FBI: "Miami Township PD, Clermont County"
    str_replace_all("[^a-z0-9 ]", " ") |> str_squish() |> str_replace_all("\\bst\\b", "saint") |>
    str_replace_all("\\bco\\b", "county") |> str_replace_all("\\btwp\\b", "township") |>
    str_replace_all("\\bsherr?iff?s?\\b", "sheriffs") |> str_replace_all("\\bmt\\b", "mount") |>
    # unambiguous big-city abbreviations
    str_replace_all(c("\\bnypd\\b" = "new york city police department", "\\blapd\\b" = "los angeles police department",
                      "\\bsfpd\\b" = "san francisco police department", "\\bnopd\\b" = "new orleans police department",
                      "\\blvmpd\\b" = "las vegas metropolitan police department"))
}

MUNI_WORDS <- "\\b(city|town|township|twp|village|borough|boro)\\b"
ORG_WORDS  <- paste0("\\b(police|pd|dept|department|dep|sheriffs|sheriff|office|so|public safety|dps|",
                     "division|bureau|agency|the|of|law enforcement|services|service|force)\\b")

parse_name <- function(x) {
  b <- basic(x)
  kind <- case_when(
    str_detect(b, "\\bsheriffs?\\b") | str_detect(b, "\\bso$") ~ "sheriff",
    str_detect(b, "\\b(police|pd|public safety|dps)\\b") ~ "police",
    TRUE ~ "none")
  prefix <- case_when(
    str_detect(b, "^(the )?(city and county of|consolidated city of)\\b") ~ "city",
    str_detect(b, "^(the )?county of\\b") | str_detect(b, "\\b(county|parish|borough)$") ~ "county",
    str_detect(b, "^(the )?(city|town|village|township|borough) of\\b") ~ "muni",
    TRUE ~ "")
  core <- b |>
    str_replace("^(the )?(city and county of|consolidated city of|city of|town of|village of|township of|borough of|county of)\\s+", "") |>
    str_replace_all("\\bpolice department\\b|\\bpolice dept\\b|\\bpolice dep\\b", " ") |>
    str_replace_all(ORG_WORDS, " ") |> str_squish()
  core2 <- core |> str_replace_all(MUNI_WORDS, " ") |> str_squish()
  # "Town of Groton" -> "groton town": lets a separate town/township agency win over the same-named city
  muni_word <- str_match(b, "^(?:the )?(city|town|village|township|borough) of\\b")[, 2]
  core_typed <- if_else(is.na(muni_word) | str_detect(core, paste0("\\b", coalesce(muni_word, "x"), "$")), NA,
                        paste(core, muni_word))
  tibble(norm = b, kind = kind, prefix = prefix, core = core, core2 = core2, core_typed = core_typed)
}
