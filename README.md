# alpr-per-department

Estimate the number of automated license plate readers (ALPRs) per US police
department. The method crosswalks crowdsourced OpenStreetMap camera data (the
DeFlock layer) to law-enforcement agencies.

Status: scaffold only. No data or analysis code yet. The task specification is
in `PROMPT.md`.

## Layout

- `PROMPT.md` - task specification for Claude Code
- `R/` - analysis scripts
- `data/raw/` - raw downloads (not tracked in git)
- `data/derived/` - cleaned and joined files
- `output/` - tables, plots, summary

## Data sources

- OpenStreetMap nodes tagged `man_made=surveillance` and
  `surveillance:type=ALPR` (Overpass API or Geofabrik extract)
- BJS Law Enforcement Agency Identifiers Crosswalk (LEAIC)
- FBI agency participation file
- Census TIGER/Line boundaries and ACS 5-year population
- The News & Observer, "Private Eyes" Flock transparency portal data
  (https://github.com/mcclatchy-southeast/private_eyes), used for validation

## Known limits

- Many OSM cameras have no operator tag.
- A spatial join assigns private, sheriff, and state cameras inside city
  limits to the local police department.
- Volunteer coverage is uneven across areas.
- LEAIC is old; newer agencies are missing.
