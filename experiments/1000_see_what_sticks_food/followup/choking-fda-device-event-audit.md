# FDA airway-clearance device report check

Reviewed November 12, 2026 for experiment statement 0290. The openFDA device event API metadata is dated November 4, 2026. Both queries retrieved all returned rows in the first response. This was an interactive search using the official public API.

| Query, with the expression URL encoded in the `search` parameter | Results retrieved |
| --- | ---: |
| `(device.device_report_product_code:QXN OR device.brand_name:LIFEVAC OR device.brand_name:DECHOKER OR device.manufacturer_d_name:LIFEVAC OR device.manufacturer_d_name:DECHOKER)` | 27 of 27 |
| `(device.brand_name:"PREPARED HERO" OR device.brand_name:VITALVAC OR device.brand_name:SAVELIX OR device.brand_name:"ANTI CHOKING" OR device.generic_name:"ANTI-CHOKING DEVICE")` | 5 of 5, all in the first result |

The endpoint was `https://api.fda.gov/device/event.json`, with `limit=100`. The diagnostic check combined the report’s `mdr_text.text` fields. The review read the 18 airway-clearance-related reports and checked all 27 for whole-word Parkinson, PD, potato, tater, baked, roast, jacket and oven variants. Nine are old Vygon PICC reports sharing the LifeVac brand string (126318, 13044, 131157, 137902, 145674, 23522, 38257, 39400, 41962).

The other reports include one paired report about a child choking on a lollipop (15043658, 16409910), two records about the same marketing complaint (23224095, 23888787), a disputed school event (21648847), grapes (24563197, 50116885), chicken with rice (50525445), the patient’s own fluid (50525549), roast beef (50525550), mango (50525595), a turkey sandwich (50525603), a marker cap (50526350) and five other records without a specific obstructing food (11586110, 24689282, 51204608, 51248601, 5781700). The roast match describes beef. No Parkinson or potato variant appeared in these narratives. [Official openFDA device event documentation](https://open.fda.gov/apis/device/event/)

The FDA’s separate March 2026 review drew on two manufacturer cohorts with 735 and 367 eligible complete-obstruction reports. The aggregate release does not disclose case-level food identity, preparation or diagnosis. Earlier published potato and Parkinson counts remain unlinked, and participant overlap with the FDA cohorts is unknown. FDA postmarket collection and underlying manufacturer records remain relevant for case linkage if public data become available. Device-event reports are a separate source with the limited coverage stated above. [FDA review DEN250012, pp. 7–16](https://www.accessdata.fda.gov/cdrh_docs/reviews/DEN250012.pdf#page=7) · [2022 published series](https://doi.org/10.3389/fmed.2021.742734)
