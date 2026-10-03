# ALPR networks in court: is it a Fourth Amendment "search"?

Research as of 2026-10-03. Quotes come from the opinions themselves unless marked **[secondary]**. "Not verified" means I could not confirm it from a primary source. Page cites are to slip opinions.

## Summary

- **Almost every court has held that ALPR use is not a search.** Courts reached that result in 2 civil challenges to whole networks, 14 federal criminal rulings and 10 state appellate rulings, including the Fifth Circuit (*Porter*, 2026) and the Massachusetts SJC (*McCarthy*, 2020).
- **Three courts have gone the other way:**
  - *United States v. Kyle* (N.D. Okla., Oct. 1, 2026): suppressed a month of multi-state Flock and VehicleManager data.
  - *Commonwealth v. Bell* (Norfolk Cir. Ct., 2024): suppressed evidence from Norfolk's 172-camera Flock network.
  - *Schmidt v. Norfolk*: the motion-to-dismiss ruling (Feb. 2025) let the claim proceed. The city won at summary judgment in Jan. 2026.
- **The rulings rest on how much data the police got, not on how big the network is.** Almost every "not a search" ruling is limited to its facts: few hits, gaps in coverage, short retention. Many courts say outright that a bigger network or more data could change the answer:
  - *McCarthy*, *Sturdivant*, *Jackson*, *Schmidt* and *Scholl*;
  - the Bea concurrence in *Yang*;
  - *W.D. Okla. Brown* and *Sidor*.
- **New Supreme Court precedent:** *Chatrie v. United States*, No. 25-112 (U.S. June 29, 2026), held 6–3 that accessing Google Location History is a search. It does not mention ALPRs. Both *Riley* (no search) and *Kyle* (search) rely on it.
- **Pending appeals:**
  - *Scholl* (7th Cir. No. 25-1847, argued Sept. 29, 2026);
  - *Schmidt* (4th Cir. No. 26-1227, fully briefed, not yet argued);
  - *Simonson* petition (Wash. Sup. Ct. No. 105237-5);
  - *Tan v. San Jose* (N.D. Cal., 474 Flock cameras; motion to dismiss heard Oct. 1, 2026; no ruling verified);
  - *U.S. v. Slaybaugh* (11th Cir. No. 25-14394, argued July 2026) **[secondary]**.

## Largest networks in "not a search" rulings

| Case | Court, date | Network described in the opinion | What the police retrieved |
|---|---|---|---|
| **U.S. v. Sturdivant**, No. 1:22-cr-615 | N.D. Ohio, June 9, 2025 (Calabrese, J.) | "1,636 Flock cameras across Cuyahoga County, 667 of which are associated with law enforcement agencies" (p. 5), plus ~1,119 ELSAG cameras (p. 7). In total, "approximately 1,800 to 3,000 cameras" (p. 26). | "at least 26 data points over the course of six weeks" |
| **Scholl & Bednarz v. Illinois State Police**, No. 1:24-cv-04435 | N.D. Ill., Mar. 31, 2025 (Pacold, J.) | "344 cameras in Cook County, 78 in St. Clair County, and 44 across 17 other counties" = **466** (p. 2). Expressway readers feeding Vigilant LEARN. | None: a civil challenge to the collection itself |
| U.S. v. Bowers, No. 2:18-cr-292 | W.D. Pa., Oct. 11, 2021 (Ambrose, J.) | Allegheny County DA, "350+ ALPRs" | 106 reads at 33 locations over 4.5 months |
| U.S. v. Jackson, No. 24-cr-10010 | D. Kan., May 29, 2025 (Broomes, J.) | Wichita Flock, 160 cameras (now 190) | ~9 hits in 4 hours |
| U.S. v. Martin, 753 F. Supp. 3d 454 | E.D. Va., Oct. 11, 2024 (Payne, J.) | Richmond (66) + Chesterfield (52) Flock **[from quotes in other opinions; full text not retrieved]** | 3 photos in 30 days |
| Schmidt v. City of Norfolk, No. 2:24-cv-621 | E.D. Va., Jan. 27, 2026 (Davis, J.) | **176** Flock cameras in 75 clusters, plus access to 43 third-party Flock cameras (p. 9) | None queried; plaintiffs captured ~475 and ~325 times in 4.5 months |
| Commonwealth v. Church; Robinson v. Commonwealth | Va. Ct. App., Oct. 14, 2025; Apr. 7, 2026 (published) | Norfolk Flock, 172 cameras | 3 images; 1 image |
| U.S. v. Riley, No. 2:25-cr-380 | C.D. Cal., Sept. 10, 2026 (Phillips, J.) | Culver City Flock, 52 cameras at 28 intersections; Carson Motorola, 85 fixed cameras + 4 trailers | 4 photos from each system |
| U.S. v. Cooper, No. 23-131 | E.D. La., Jan. 6, 2025 | New Orleans, ~60 cameras | — |
| State v. Faile, 2026-UP-323 | S.C. Ct. App., July 1, 2026 | Rock Hill Flock, 24 cameras | 2 photos |
| U.S. v. Porter, No. 25-60163 | 5th Cir., Mar. 17, 2026 | Gautier, MS, "no more than ten" cameras | Real-time hit plus earlier hits |
| Commonwealth v. McCarthy, 484 Mass. 493 | Mass. SJC, Apr. 16, 2020 | 4 cameras on 2 bridges | ~2.5 months of crossings |

The plot `density_cameras_per_agency_court_cutoff.png` draws a line at 1,636 (Sturdivant) and at 466 (Scholl). The two numbers measure different things:
- **Sturdivant** is a criminal suppression ruling about *queries* of a county-wide, multi-owner network. Only 667 of its cameras are tied to law enforcement.
- **Scholl** is a civil challenge to one agency's *collection*, on a motion to dismiss.

---

## 1. Civil challenges to whole networks

### Scholl & Bednarz v. Illinois State Police, No. 1:24-cv-04435 (N.D. Ill. Mar. 31, 2025), 776 F. Supp. 3d 701; appeal 7th Cir. No. 25-1847
- **Posture:** The court granted the 12(b) motion to dismiss and denied the preliminary injunction. Final judgment May 2, 2025.
- **Appeal:** Argued **Sept. 29, 2026** before Brennan, C.J., St. Eve and Taibleson, JJ. The United States filed an amicus brief supporting ISP. No decision yet. **[secondary]** Reports say the panel seemed skeptical of the plaintiffs.
- **Network:**
  - 466 ISP expressway cameras feeding Vigilant LEARN. The vendor is named in the appellants' brief, not the opinion.
  - "Last month, ALPRs in Illinois recorded 200,161,762 detections and 5,747,483 hits" (p. 3).
  - Retention: up to 120 days by statute; "generally" 90 days in LEARN.
- **Standing:** Plaintiffs had standing to challenge collection but **not** LEARN queries, which were not imminent (pp. 6–7).
- **Holding:** "when an ALPR scans a license plate, it does not conduct a 'search'" (p. 10).
- **Reasoning:**
  - The system is "more akin to the beeper in Knotts … or to the stationary pole cameras in Tuggle" (p. 17).
  - The court follows the 7th Circuit's skepticism of the mosaic theory (p. 12).
  - It concedes some *Carpenter* factors are present: the data is retrospective, and it "runs against everyone."
- **Reservation:** "The court does not decide whether a more extensive network of ALPRs might infringe a reasonable expectation of privacy" (p. 18).

### Schmidt & Arrington v. City of Norfolk, No. 2:24-cv-00621 (E.D. Va.); appeal 4th Cir. No. 26-1227
- **MTD ruling, Feb. 5, 2025: denied.**
  - The complaint alleged 172 cameras and "the whole of tens of thousands of individual's movements," which the court found "notably similar to those in Carpenter" (p. 19).
  - The court cautioned that this "is not a preview of the likely resolution" (p. 19 n.9).
- **Summary judgment, Jan. 27, 2026: for the city.**
  - Network: 176 cameras in 75 clusters; 30-day retention, now 21 days under Va. Code § 2.2-5517. "75 Flock camera clusters therefore monitor a very small percentage of Norfolk's public roadways" (pp. 9–10).
  - Holding: The evidence is "insufficient to demonstrate that Defendants' current ALPR system captures enough images … to reconstruct the whole of their movements" (p. 35).
  - On *Carpenter*: "the average number of captures in Carpenter were 30 to 50 times greater" (p. 37).
  - On *Beautiful Struggle*: "many thousands more blind spots than it has unblinking eyes" (p. 38).
  - Mosaic theory rejected for "2 or 3 … scattered ALPR data points" (p. 49).
- **Reservation:** "ALPR surveillance could become too intrusive … at some point. But when? … at least in Norfolk, Virginia, the answer is: not today" (p. 6). See also p. 42 n.17: cameras at "the next street corner, and the next" might change the result.
- **Appeal:** Fully briefed. Amici for appellants include EPIC and Cato. No argument date verified.
- **Quote caveat:** The quotes come from OCR of a scanned PDF. Check them against the original.

### Neal v. Fairfax County Police Dep't (Va. 2018; Va. 2020): statutory, not Fourth Amendment
- **2018:** Passive ALPR collection (364-day retention) can be "personal information" under the Virginia Data Act. Remanded.
- **2020:** Reversed the injunction, because the ALPR database itself does not identify individuals. Final.

### Pending civil suits (no merits ruling verified)
- **Tan v. City of San Jose**, No. 5:26-cv-03181-BLF (N.D. Cal.), Institute for Justice: 474 Flock cameras, 30-day retention. **If the court dismisses on the merits, this would be the largest single-agency network held constitutional.**
- **SIREN v. San Jose** (Cal. Super. Ct.), **[secondary]** Cal. Const.
- **Grimmett v. Wichita** (Kan.), **[secondary]**.
- **ACLU/PANA v. San Diego** (filed Sept. 30, 2026), **[secondary]**.
- **Suits against Flock as vendor** (N.D. Cal., N.D. Ga.), **[secondary]**.

## 2. Federal criminal rulings

### Search found
**U.S. v. Kyle**, No. 4:26-cr-00189-SEH (N.D. Okla. Oct. 1, 2026) (Hill, J.), Dkt. 62.
- **Facts:**
  - A Tulsa County deputy queried Flock and VehicleManager.
  - He got "more than 50 individual records of Kyle's whereabouts across the country for an entire month" (p. 37).
  - The opinion gives no camera count.
- **Holding:**
  - "This is a type of indiscriminate mass surveillance … It is a tool that collects information about all vehicles that pass by any network-connected camera at all times" (p. 34).
  - It was a search without a warrant or probable cause.
- **Reasoning:** Relies on *Carpenter*, *Chatrie* and *Kyllo*. Says "lower courts need to reexamine the result in Knotts" (p. 31).
- **Caveat:** Suppression also rests on an independent ground, an unlawfully extended stop. **[secondary]** Flock told the press it expects an appeal.

### Not a search
- **U.S. v. Porter**, No. 25-60163 (5th Cir. Mar. 17, 2026) (Smith, J.), published. **The only circuit merits holding.**
  - Network: ~10 cameras.
  - "The LPR system is not capable of tracking the 'whole of [an individual's] physical movements'" (p. 7). The system is "more analogous to the beeper signals in Knotts."
- **U.S. v. Riley**, No. 2:25-cr-380-VAP (C.D. Cal. Sept. 10, 2026).
  - Networks: Culver City Flock, 52 cameras / 30 days; Carson Motorola, 85 cameras.
  - Retrieved: 4 photos from each system.
  - "The record here does not reveal a privacy threat analogous to … Carpenter and Chatrie" (p. 7).
- **U.S. v. Sturdivant** (N.D. Ohio June 9, 2025): see the table above.
  - The court called it a "close and difficult" question.
  - "That day might well be on the horizon … the record here shows a qualitative leap forward, placing the evidence generated from such technology at risk in the absence of a warrant" (pp. 27–28).
- **U.S. v. Jackson** (D. Kan. May 29, 2025):
  - Network: Wichita, 160–190 Flock cameras, "roughly one camera per 2.6 lane miles."
  - Reservation: wider deployment "could eventually rise to the level of systemic and continuous tracking" (p. 20).
- **U.S. v. Martin** (E.D. Va. 2024): Richmond-area Flock; one query returned the 2,500-result maximum; 3 photos of the defendant. Full text not retrieved.
- **U.S. v. Bowers** (W.D. Pa. 2021): 350+ cameras; 106 reads over 4.5 months. Good faith in the alternative.
- **U.S. v. Yang**, 958 F.3d 851 (9th Cir. 2020):
  - The majority decided on standing only (an overdue rental car).
  - Bea, J., concurring: no search, but "if the database evolves to provide comparable location information to the records at issue in Carpenter," a warrant may be required.
- **U.S. v. Mapson**, 96 F.4th 1323 (11th Cir. 2024): decided on good faith only.
- **Other district rulings:**
  - Rubin (N.D. Cal. 2021)
  - Brown (N.D. Ill. 2021: 23 sightings over 10 weeks)
  - Porter (N.D. Ill. 2022)
  - Graham (D.N.J. 2022)
  - Toombs (N.D. Ala. 2023)
  - Jiles (D. Neb. 2024)
  - Cooper (E.D. La. 2025)
  - Brown (W.D. Okla. 2025: 3 Choctaw Flock cameras, with the reservation "could significantly expand … to a point where the number of cameras allowed for pervasive, widespread tracking")
  - Schoggins (E.D. Okla. 2026)
- **Status:** Appeal status for the district cases is not verified.

## 3. State courts

### Search found (trial court only)
**Commonwealth v. Bell** (Norfolk Cir. Ct. May 10, 2024) (LeCruise, J.), 113 Va. Cir. 316.
- **Network:** 172 Flock cameras, 30-day retention.
- **Holding:** "due to the breadth of FLOCK cameras covering the entire City of Norfolk and the storage component [it] is also akin to a GPS device and requires a warrant."
- **Status:** Never reviewed on appeal. Effectively superseded by *Church* and *Robinson*.

### Not a search
- **Commonwealth v. McCarthy**, 484 Mass. 493 (2020), SJC-12750. **The leading statement of when ALPRs *would* be a search.**
  - Network: 4 cameras on the Cape Cod bridges; 1-year retention.
  - "With enough cameras in enough locations, the historic location data from an ALPR system in Massachusetts would invade a reasonable expectation of privacy and would constitute a search."
  - "While we cannot say precisely how detailed a picture … must be revealed to invoke constitutional protections, it is not that produced by four cameras at fixed locations on the ends of two bridges."
  - ALPRs near "the home, a place of worship" reveal more. Real-time hot-list alerts deployed widely enough could be "the vehicular equivalent of a cellular telephone 'ping.'"
- **Robinson v. Commonwealth** (Va. Ct. App. Apr. 7, 2026, **published**, binding in Virginia):
  - Norfolk's 172 cameras are not "near perfect surveillance."
  - The court "decline[s] to speculate as to when—or if."
- **Commonwealth v. Church** (Va. Ct. App. Oct. 14, 2025, unpublished): reversed the trial court's suppression. "[T]he 172 Flock cameras in use in Norfolk are not as intrusive as cell towers and aerial surveillance."
- **Norfolk and Chesterfield trial courts:** *Robinson*, *Roberson*, *Reap* and *Adams* (2024) all denied suppression.
- **State v. Simonson** (Wash. Ct. App. Jan. 29, 2026, amended Mar. 5, 2026):
  - Held under art. I, § 7 of the Washington Constitution.
  - "The amount of photographs taken … is inconsequential."
  - A petition for review is pending.
- **State v. Sidor**, 558 P.3d 621 (Ariz. Ct. App. 2024): "not yet a search … in a future more rife with cameras, it might well be a search" (¶41).
- **Commonwealth v. Watkins**, 304 A.3d 364 (Pa. Super. 2023): not a search. Olson, J., dissented and would find a search.
- **State v. Faile** (S.C. Ct. App. 2026): not a search under the Fourth Amendment **and** S.C. Const. art. I, § 10, which expressly protects privacy.
- **Other state rulings:**
  - Uhunmwangho v. State (Tex. App. 2020)
  - Traft v. Commonwealth (Ky. 2018)
  - People v. Gonzalez (Cal. Ct. App. 2019: did not decide; any error harmless)
  - Hill v. State (Ga. Ct. App. 2013)
- **Not verified:**
  - Junction City v. $454,280 (Kan. Ct. App. 2023)
  - Canosa v. Coral Gables (Fla. 3d DCA 2023)
  - State v. Xique (Minn. Dist. Ct. 2026)

## 4. Sources (primary unless marked)
- Scholl: https://cases.justia.com/federal/district-courts/illinois/ilndce/1:2024cv04435/459495/41/0.pdf ; appellants' brief https://libertyjusticecenter.org/wp-content/uploads/Scholl-v.-ISP-Appellants-Br-and-Short-Appendix-FINAL.pdf ; 7th Cir. calendar https://media.ca7.uscourts.gov/oralArguments/oar.jsp
- Schmidt: MTD https://epic.org/wp-content/uploads/2025/02/Schmidt-Order-Denying-MTD-.pdf ; SJ https://ij.org/wp-content/uploads/2026/01/Order-1-27-26.pdf ; EPIC amicus https://epic.org/wp-content/uploads/2026/04/EPIC-Amicus-Schmidt-v.-Norfolk.pdf
- Neal: https://www.vacourts.gov/opinions/opnscvwp/1170247.pdf ; https://www.vacourts.gov/opinions/opnscvwp/1191127.pdf
- Tan v. San Jose complaint: https://ij.org/wp-content/uploads/2026/04/Doc.-1-Complaint-for-Declaratory-and-Injunctive-Relief.pdf
- Chatrie: https://www.supremecourt.gov/opinions/25pdf/25-112_0am4.pdf
- Porter: https://www.ca5.uscourts.gov/opinions/pub/25/25-60163-CR0.pdf
- Riley: https://drive.google.com/file/d/1PeM02GyDiOg0v8cWXfxfxgXLU1lZEio0/view
- Kyle: https://storage.courtlistener.com/recap/gov.uscourts.oknd.76981/gov.uscourts.oknd.76981.62.0.pdf
- Sturdivant: https://www.govinfo.gov/content/pkg/USCOURTS-ohnd-1_22-cr-00615/pdf/USCOURTS-ohnd-1_22-cr-00615-0.pdf
- Jackson: https://ecf.ksd.uscourts.gov/cgi-bin/show_public_doc?2024cr10010-48+=
- Yang: https://cdn.ca9.uscourts.gov/datastore/opinions/2020/05/04/18-10341.pdf
- Mapson: https://media.ca11.uscourts.gov/opinions/pub/files/202211159.pdf
- Bowers: https://www.govinfo.gov/content/pkg/USCOURTS-pawd-2_18-cr-00292/pdf/USCOURTS-pawd-2_18-cr-00292-19.pdf
- Rubin: https://www.govinfo.gov/content/pkg/USCOURTS-cand-3_18-cr-00568/pdf/USCOURTS-cand-3_18-cr-00568-2.pdf
- Brown (N.D. Ill.): https://www.govinfo.gov/content/pkg/USCOURTS-ilnd-1_19-cr-00949/pdf/USCOURTS-ilnd-1_19-cr-00949-0.pdf
- Cooper: https://www.govinfo.gov/content/pkg/USCOURTS-laed-2_23-cr-00131/pdf/USCOURTS-laed-2_23-cr-00131-0.pdf
- Brown (W.D. Okla.): https://www.govinfo.gov/content/pkg/USCOURTS-okwd-5_25-cr-00188/pdf/USCOURTS-okwd-5_25-cr-00188-0.pdf
- Martin **[secondary excerpt]**: https://case-law.vlex.com/vid/united-states-v-martin-1056100094
- McCarthy **[FindLaw copy]**: https://caselaw.findlaw.com/court/spr-jud-crt-mas-bar/2060202.html
- Church: https://www.vacourts.gov/static/opinions/opncavwp/0737251.pdf ; Robinson: https://www.vacourts.gov/static/opinions/opncavwp/1912241.pdf
- Bell and other Virginia trial rulings: https://vscc.virginia.gov/2024/Nov14mtg/VSCC%20ALPR%20VA%20Court%20Opinions%20FINAL%20-%20full%20opinions.pdf
- Simonson: https://www.courts.wa.gov/opinions/pdf/407322_unp.pdf
- Sidor: https://azcourts.gov/Portals/0/OpinionFiles/Div1/2024/1%20CA-CR%2022-0387%20STATE%20v.%20SIDOR.pdf
- Watkins: https://cases.justia.com/pennsylvania/superior-court/2023-2209-eda-2021.pdf
- Faile: https://www.sccourts.org/media/opinions/unpublishedopinions/HTMLFiles/COA/2026-UP-323.pdf
