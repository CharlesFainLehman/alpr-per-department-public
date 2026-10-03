Goal: estimate the number of automated license plate readers (ALPRs) per US
police department, using crowdsourced OpenStreetMap data (the DeFlock layer)
crosswalked to law-enforcement agencies. Work in R. Save all scripts, raw
downloads, and outputs in this project folder so the analysis is reproducible.

1. PULL THE CAMERA DATA
- Query the Overpass API for all US nodes tagged man_made=surveillance with
  surveillance:type=ALPR. Query state by state to avoid timeouts. If Overpass
  fails, use a Geofabrik US extract and filter it.
- Keep: OSM id, lat, lon, manufacturer, operator, operator:type, brand,
  surveillance (public/private), surveillance:zone, and the last-edit
  timestamp.
- Save the raw pull with the download date. Report total cameras, counts by
  manufacturer, and the share with a non-empty operator tag.

2. BUILD THE AGENCY LIST
- Download the BJS Law Enforcement Agency Identifiers Crosswalk (LEAIC, ICPSR
  35158) and a current FBI agency participation file (ORI, agency name, agency
  type, state, population served). If ICPSR needs a login, stop and tell me
  which file to download by hand.
- Keep only local police departments and sheriff's offices. Each should have
  ORI, name, type, state, place FIPS or county FIPS, and population served.
- Download Census TIGER/Line place and county boundaries (latest year) and
  ACS 5-year population for places and counties.

3. CROSSWALK, TWO METHODS
A. Operator tag. Normalize the operator text (case, punctuation, "PD",
   "Police Dept", "Sheriff's Office", "City of X") and match to agency names
   within the same state. Use exact match first, then fuzzy match with a
   strict threshold. Write all fuzzy matches to a file for my review. Do not
   accept a fuzzy match across states.
B. Spatial join. Assign each camera to the Census place that contains it. If
   it is in no place, assign it to the county. Then assign place cameras to
   the municipal PD and unincorporated-county cameras to the sheriff.
- Exclude from method B any camera whose tags show a private operator (HOA,
  business, retailer, school) or surveillance=private. Report how many were
  excluded.
- Keep both assignments on each camera row, so I can see where A and B
  disagree.

4. VALIDATE
- Clone https://github.com/mcclatchy-southeast/private_eyes. Use
  data/latest_usage04262023.csv, column number_of_owned_cameras. Drop rows
  whose agency name contains "Flock", "Training", or "DNU". These are
  agency-reported Flock camera counts from April 2024 for about 328 agencies.
- Match those agencies to my agency list. Compare the reported count to the
  method A count and the method B count (Flock-manufacturer cameras only).
- Report: correlation, median ratio, median absolute error, and a scatter
  plot on log axes for each method. Note that the OSM data are newer, so
  counts above the 2024 figure are expected.

5. OUTPUTS
- cameras.csv: one row per camera with both agency assignments.
- agencies.csv: one row per agency with ORI, name, type, state, population,
  cameras by method A, cameras by method B, cameras per 10,000 residents.
  Include agencies with zero cameras.
- A short summary: mean, median, and percentiles of cameras per agency, (a)
  for agencies with one or more cameras and (b) for all agencies; the same
  split by agency type and by population bin; and the validation results.
- A density plot of cameras per agency on a log x-axis.

RULES
- Accuracy matters more than speed. Do not guess. If a download, match, or
  join is uncertain, report it and say how many rows it affects.
- Print row counts before and after every join and filter.
- State every limit of the data in the summary: untagged operators, private
  cameras inside city limits, overlapping jurisdictions, uneven volunteer
  coverage, and the age of LEAIC.
- Do not use any leaked or non-public Flock data.
