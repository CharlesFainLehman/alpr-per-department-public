# Optional: snapshot the operator tables on Finding Flock (https://www.findingflock.com/operators), an
# anti-surveillance site that tallies OpenStreetMap ALPR cameras by the organization their `operator` tag names,
# split into private operators, public agencies and cameras recorded as the vendor. It lists only operators with at
# least five tagged cameras. Its data are OpenStreetMap's (ODbL), so its counts are a subset of the same map this
# project uses: cameras someone tagged with an operator.
# Writes data/snapshots/findingflock_operators_<date>.csv (section, operator, cameras, where), read by 09_charts.R.
source("R/00_setup.R")

html <- paste(readLines(url("https://www.findingflock.com/operators", headers = c(`User-Agent` = "alpr-per-department (research)")),
                        warn = FALSE), collapse = "\n")
html <- gsub("(?s)<script.*?</script>", "", html, perl = TRUE)
text <- function(x) str_squish(xml2::xml_text(xml2::read_html(paste0("<p>", x, "</p>"))))
# Each table follows the <h2>/<h3> heading that names its section.
parts <- str_split(html, "(?=<h[23][ >])")[[1]]
rows <- map_dfr(parts, \(p) {
  heading <- text(str_match(p, "(?s)^<h[23][^>]*>(.*?)</h[23]>")[, 2] %||% "")
  trs <- str_match_all(p, "(?s)<tr[^>]*>(.*?)</tr>")[[1]][, 2]
  map_dfr(trs, \(tr) {
    cells <- map_chr(str_match_all(tr, "(?s)<t[dh][^>]*>(.*?)</t[dh]>")[[1]][, 2], text)
    if (length(cells) < 2 || !str_detect(cells[2], "^[0-9,]+$")) return(NULL)
    tibble(section = heading, operator = cells[1], cameras = as.integer(str_remove_all(cells[2], ",")),
           where = if (length(cells) > 2) cells[3] else "")
  })
})
n_log(rows, "operator rows")
print(count(rows, section, wt = cameras))
stopifnot(nrow(rows) > 0, all(c("Public agencies", "Private operators") %in% rows$section))
write_csv(rows, file.path("data/snapshots", sprintf("findingflock_operators_%s.csv", format(Sys.Date()))))
