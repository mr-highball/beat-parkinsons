# Direction review for all Unknown claims

The November 19, 2026 UTC snapshot includes all 940 Unknown claims. The first queue omits the frozen reduces or worsens direction while keeping the ingredient, preparation and symptom visible. Within each review lane, the native tool interleaves the eight food, herb, spice and oil direction groups. The strata file records denominators, including the original 125 frozen claims per group. Assign any eventual grade against the original wording after reviewing the evidence.

| First applicable review lane | Claims |
| --- | ---: |
| Assessment wording suggests a human comparison | 55 |
| Open indexed or archived source may contain relevant context | 2 |
| Other existing assessments | 100 |
| No nonpending assessment | 0 |
| Prior weak-direction review with unchanged recorded evidence | 783 |

Comparison wording and archive coverage prioritize reading. They can miss pertinent sources or flag comparators, preparations or symptoms that do not fit. The 4,047 assessment pointers are a separate reading aid. The prior review ledger records 1,000 adjudications, with 60 claims currently graded Maybe. Of those records, 991 have a recorded SHA-256 fingerprint of the reviewed assessment rows. The nine earlier reviews continue to use their saved row count until a reviewed snapshot or fresh check can support a fingerprint.

A changed row count or a changed fingerprint returns a previously reviewed Unknown to the ordinary priority lanes. The fingerprint uses the study key, role, fit, local locator and finding without depending on row order. Catalog or primary-source changes that leave these ledger fields untouched still require a recheck. The fingerprint supplies no evidence direction or strength. The queue preserves claims in every lane.

Use the dedicated coverage-gap queue alongside the ranking. When the comparison lane is thin for a category and direction, use that group's open-context work. Follow pending trials and exact source-access leads even for claims with current assessment fingerprints. [Coverage gaps](../coverage-current/claim-gap-queue-masked.tsv) · [Exact source coverage](../context-coverage/README.md)

Review the original outcomes and methods, check study overlap, consider directions, and record uncertainty about preparation, population and symptom. Follow unresolved source leads and file eligible research in its chronological bucket.

Run from the repository root.

    & ./experiments/1000_see_what_sticks_food/tools/build-unknownadjudication.ps1

The wrapper invokes Athena FPC and writes under the ignored build directory. It checks the frozen IDs and hash. Past adjudications may give a fourth column `reviewed_evidence_fingerprint` from the same ledger snapshot as the completed review. Leave the field blank for historical entries whose reviewed snapshot cannot be established. The format is `sha256-v1:` followed by the lowercase hex checksum. The native replay produced identical published tables in an independent repeat. A separate edit to a signed 0030 assessment changed only that claim's review priority with its assessment count and verdict intact.

[Direction-masked worklist](unknown-worklist-masked.tsv) · [Strata counts](unknown-worklist-strata.tsv) · [Assessment locators](unknown-assessment-locators.tsv) · [Prior review status](prior-review-status.tsv) · [Per-claim evidence fingerprints](claim-evidence-fingerprints.tsv) · [Run input fingerprints](input-sha256.tsv) · [First review completion](../masked-twenty-ninth-nov16/README.md) · [Latest signed recheck](../tremor-direction-nov19-27/README.md)

The evidence-tier reassessment is tracked separately from the Unknown queue. Seven of the 1,000 claims have a version 1 scorecard. The [fig scorecard](../tremor-fig-nov19-30/README.md) was checked before publication. See the [first versioned scorecards](../tremor-scorecard-nov19-28/README.md) for the olive-oil revision and preserved historical grading.
