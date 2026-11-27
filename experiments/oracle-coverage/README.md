# Oracle research coverage

[First-pass lookups](lookups.tsv) · [Batch rates and priorities](batches.tsv)

Make one first-pass record for each distinct evidence question in a batch. An
ingredient and symptom question belongs to `claim_evidence`. Retrieval or
verification of a defined paper, trial, or collection belongs to
`source_verification`. Record the actual query terms and any local citations.
Alias searches, extra result pages, and repeat checks after catalog expansion
belong to the same question and do not add denominator rows.

| Outcome | Meaning |
| --- | --- |
| `hit` | Verified local evidence answers the assigned question at the required depth. Evidence in either direction or a conclusive eligibility exclusion can qualify. |
| `partial` | A local lead exists, with a material gap in exposure, preparation, population, endpoint, data, or source access. |
| `miss` | Relevant local searches completed without a usable lead for the assigned question. |
| `unavailable` | The lookup could not be evaluated because the oracle or index was unavailable, stale, or unreadable for the relevant material. |

Strict hit rate is `hits / (hits + partials + misses)`. Lead rate also counts
partials in the numerator. Record both with their counts. Keep unavailable
questions visible outside the rate and investigate those failures independently.
When an oracle lookup repeatedly stalls, use the same queries against the
native server and the affected transport to locate the delay. Compare source
identifiers, broader terms and paged results on the same catalog snapshot.
Address measured bottlenecks and verify result order, totals and coverage
diagnostics before recording an improvement.

Compare matching workstream and question types, then inspect exposure and symptom
groups. A declining rate calls for review of the underlying gaps and sample size.
When comparable batches keep declining, move recurring catalog gaps up the
research queue. Keep reporting unresolved questions and access limits regardless
of the local hit rate.

Dexter records the initial result before adding new evidence. After integrating
new sources into their chronological buckets, refresh the index and verify
retrieval. Use batch summaries to identify the gaps that motivate that work.
Record only research identifiers and relative source paths.

For cultural or forum source questions, use [Oracle catalog search](../tools/parkinsons-oracle/README.md#cultural-and-conversational-lookup) before external discovery. Record the `source_kind` filter with the lookup terms when used. A matching discussion can verify that an account was reported. Preparation, diagnosis, and symptom mismatches still matter when judging a frozen ingredient claim. Verify new chronological entries through MCP after refresh without counting the verification as another first pass.

## Validate a coverage append

The native [coverage merger](../tools/parkinsons-oracle/oraclecoverage.merge.lpr) validates the old and proposed question and aggregate tables before writing distinct staged outputs under `build/`. It rejects duplicate question identities, duplicate aggregate keys, malformed rows, orphan groups, invalid outcomes, count/rate mismatches and input overwrite. Existing table bytes and order remain exact prefixes. An aggregate key includes batch, workstream and lookup kind; a question key includes batch and question. Unavailable lookups stay outside rate denominators.

```powershell
$run = 'build/oracle-coverage-merge'
New-Item -ItemType Directory -Force "$run/units", "$run/bin" | Out-Null
fpc -B -Sa -Cr -Co -Ci -gl "-FU$run/units" "-FE$run/bin" experiments/tools/parkinsons-oracle/oraclecoverage.merge.lpr
& "$run/bin/oraclecoverage.merge.exe" experiments/oracle-coverage/lookups.tsv experiments/oracle-coverage/batches.tsv "$run/new-lookups.tsv" "$run/new-batches.tsv" "$run/combined-lookups.tsv" "$run/combined-batches.tsv"
```

Prepare new rows in the existing schemas, verify the staged combined files, and publish both only after exit zero. This verifies accounting rather than whether an evidence question was substantively answered. The [native fixtures](../tools/parkinsons-oracle/oraclecoverage.merge.tests.lpr) take the merger executable and a fresh ignored fixture directory. The November 17 checkpoint preserves [15 passing fixtures](../1000_see_what_sticks_food/followup/lemon-balm-depression-nov17-09/oracle-merge-fixtures.txt) and [the actual 37-question append](../1000_see_what_sticks_food/followup/lemon-balm-depression-nov17-09/oracle-merge-verification.txt).

## Exact ClinicalTrials.gov lookups

A November 17 inventory found two canonical NCT records with matching official URLs under labeled header fields that revision 55 did not recognize. The native parser now reads those fields and requires the same official host, path and matching identifier as the other recognized source formats. Conflicting IDs are rejected. The registry identifier refresh backfills unchanged files. At revision 56 both records and five sampled existing matches returned their canonical paths through the same exact requests. A repeated refresh retained the revision. The reproduced index failure is recorded as unavailable in the first-pass rate. [NCT03532789](../../research/2015-2019/Source-Text/Trials/NCT03532789.txt) · [NCT05602688](../../research/2020-2024/Source-Text/Trials/NCT05602688.txt)

## Exact ANZCTR short links

Two canonical ACTRN records use the WHO-linked ANZCTR short form with the entire registry ID in the path. Revision 58 missed both. The parser also accepts that official short form when its ID matches the record header and filename. It rejects another ID and lookalike hosts. The upgraded index returned both exact records at revision 59 and preserved four sampled ClinicalTrials.gov, IRCT and ISRCTN controls. The result for the lemon balm pilot points to a WHO/government bridge extract. Direct ANZCTR body access remains unresolved. [Teenagers trial](../../research/2025-2029/Source-Text/Trials/ACTRN12625000047493.txt) · [Lemon balm pilot](../../research/2025-2029/Source-Text/Trials/ACTRN12626001145392.txt)

The IRCT older-women record uses its official Persian page as the source and its official English page as the `URL` field. Exact lookup returned zero matches at revision 59 and one at revision 60 after the header update. Seven other exact lookups retained their paths, including both ANZCTR records. The Persian and English intervention wording differs. [Bilingual registry record](../../research/2020-2024/Source-Text/Trials/IRCT20150519022320N32.txt)

## Exact UMIN trial lookup

The UMIN crossover lookup returned an unsupported-identifier error. Lexical search found the archived protocol and left outcomes open. The native parser now recognizes exact UMIN identities in leading registry provenance together with an official view URL. Receipt numbers have a separate namespace. The initial index returned 35 paths for 31 trial IDs at revision 62, including four later companion records. Four other filename IDs lacked sufficient header identity and returned zero paths. Eight sampled non-UMIN responses retained their complete paths and order. A repeat refresh kept revision 62 and zero read errors. Official receipt and trial-identity checks then supported four minimal header additions. Revision 63 verified all 39 paths across 35 trial IDs. The source-index extension preserves each extract’s stated depth. [Brewed lemon balm crossover](../../research/2020-2024/Source-Text/Trials/UMIN000055134.txt) · [Four verified mappings](../1000_see_what_sticks_food/followup/lemon-balm-depression-nov17-06/umin-header-identities.tsv)

## November 17 source-depth checkpoint

The twenty-third and twenty-fourth no-archive original-source batches each returned zero strict hits out of six at revision 66, continuing the same source-coverage gap. Fourteen evidence questions were added overall: those twelve source misses, one historical chapter miss at revision 66 and a partial cinnamon claim question at revision 67. The chapter's known-ID web-before-Oracle ordering exception remains explicit. Walnut-human searches and repeated source-role checks continue earlier questions and add no denominators. The separate managed-MCP binding failure is technical unavailability, with 0/0 evidence rates. Native merge preserves the earlier question and aggregate rows in bytes and order. [Evidence and remaining scope](../1000_see_what_sticks_food/followup/lemon-balm-depression-nov17-10/README.md) · [Merge proof](../1000_see_what_sticks_food/followup/lemon-balm-depression-nov17-10/oracle-merge-verification.txt)

The fig resting-tremor checkpoint found an existing lead for the claim question and one source-summary lead across six distinct source-verification questions. The initial local searches had zero strict hits. Focused expansion added five fig-related records by publication period. The recovered conference collections continued existing exact-source questions outside this denominator. [Search and evidence checkpoint](../1000_see_what_sticks_food/followup/tremor-fig-nov19-30/README.md)

Five newly defined turkey meal and conversation source questions gave zero exact first-pass hits. An older protein-challenge record supplied general local context. The original proceedings checks continued earlier questions. The expansion indexed specific meal contrasts and a firsthand turkey account while preserving the absence of a separate symptom result. [Turkey evidence and access coverage](../1000_see_what_sticks_food/followup/tremor-turkey-nov19-31/README.md)

The grapefruit checkpoint had zero exact first-pass hits for seven newly defined clinical and conversational source questions. One question had an existing narrative locator for the Japanese concentration figure. The initial claim lookup continued the previously recorded question. The indexed additions distinguish fresh pulp, juice, injected constituents and a flavored drink. [Grapefruit checkpoint](../1000_see_what_sticks_food/followup/tremor-grapefruit-nov19-32/README.md).

The toasted fennel checkpoint revisited three narrative locators and recovered their exact article identities and outcomes. Source questions about toxicity, food preparations and traditional use identified missing standalone records, while earlier archived constituent studies were reused. [Fennel evidence and source coverage](../1000_see_what_sticks_food/followup/tremor-fennel-nov19-33/README.md).

The raw cantaloupe checkpoint found four exact archive hits across fourteen distinct source questions, plus a local lead for the separate claim question. The additions recover an original motor supplement, linked cohort, cultivar-specific comparisons, two registrations and traditional documentation. The known fig use of the shared diet paper adds no repeat source question. [Cantaloupe evidence and source depth](../1000_see_what_sticks_food/followup/tremor-cantaloupe-nov19-34/README.md).

The peanut-oil checkpoint found two exact hits and one partial across eighteen distinct source questions. The partial was a historical index receipt. The expansion recovered the original Parkinsonian measurements and added oral-oil, trial-registry and traditional-practice records. [Peanut-oil evidence and original pages](../1000_see_what_sticks_food/followup/tremor-peanut-oil-nov19-35/README.md).

The macadamia-oil checkpoint found six exact archive hits across 15 new source questions, all registrations, and contextual leads for the separate claim question. The original 1994 body and the older poison-center follow-up were recovered through continued identifier trails. [Macadamia-oil evidence](../1000_see_what_sticks_food/followup/tremor-macadamia-nov19-36/README.md).

The strawberry-and-falls checkpoint recorded zero strict hits and three partial locators for 112 original-source questions. A separate companion batch recorded six misses. The fisetin registry check continued an existing source question. The original-source hit rate highlights a body-depth gap for these older extracts and official collections. [Review and body access](../1000_see_what_sticks_food/followup/strawberry-falls-originals-nov19-38/README.md).

The strawberry First Foods entry was already searchable with the cultural filter. Exact lookup initially missed its three verified publication keys because the identifier index covered only the study archive tree. After the cultural metadata backfill at index revision 105, the PMID, PMCID and DOI all returned the same local record. Seven exact source controls kept their paths and order. The filtered text results were unchanged. [Oracle publication identity rules](../tools/parkinsons-oracle/README.md#exact-source-identifiers).

The shared 2018–2019 proceedings checkpoint recorded zero strict hits across five original-source questions and five linked-source questions, with one partial local scope note. The older geriatric original was already in the ledger. Official proceedings and linked reports closed specific archive gaps. [Proceedings and remaining access routes](../1000_see_what_sticks_food/followup/shared-proceedings-nov19-45/README.md).

The 2004 EASD and 2011 SGIM follow-up produced zero strict hits for eight newly identified companion-source questions at revision 115. The main proceedings were prior first-pass questions. The dated additions include the separately published erratum and linked primary reports. [Original member evidence](../1000_see_what_sticks_food/followup/sgim-easd-originals-nov19-46/README.md).

The 2018 obesity congress review had zero strict hits across fourteen new companion-source questions at revision 116. The original congress lookup was already on record. The newly indexed records document publications and registrations while retaining cohort and food-preparation gaps. [Congress and companion coverage](../1000_see_what_sticks_food/followup/eco-obesity-originals-nov19-47/README.md).

## Local launcher

Use the project's direct MCP tools when they are visible. Otherwise launch the
same server from the repository root and select the fields needed for the
assignment. This example checks the local evidence ledger for an exact pair.

```powershell
$Request = @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'oracle_query'
        arguments = @{ ingredient = 'black tea'; symptom = 'tremors'; scope = 'assessed'; limit = 3 }
    }
}
$Reply = $Request | ConvertTo-Json -Depth 6 -Compress |
    pwsh -NoProfile -File ./experiments/tools/parkinsons-oracle/serve.ps1 |
    ConvertFrom-Json
$Reply.result.content[0].text | ConvertFrom-Json
```

Use `oracle_status` to record the claim and catalog revisions. For a batch of
known study identifiers, call `oracle_find_sources` with, for example,
`identifiers: ["PMID:40647065", "NCT04986982", "ACTRN12610000710022"]`.
Exact lookup also accepts ISRCTN, IRCT and DRKS IDs. Use `oracle_read_source`
with the returned `path` to verify identity, eligibility and depth. Pass each
`next_offset` as `offset` when you need more of a long source. When archive matches are
empty, use `oracle_search_catalog` to find citations and catalog notes before
classifying a question. Use the text search for alternate terms, then review the
assessments needed to check evidence and conflicts.
If a focused follow-up already identifies a study in the claim ledger, pass
its exact `assessment_study` key to `oracle_claim` without paging. The result
includes every row for that key and the claim-wide verdict and coverage.
Zero matching rows means the key is absent from that claim's ledger at the
returned revision. Use the catalog and source checks for the underlying study.
When triaging an evidence-heavy claim, start with `oracle_claim` and
`assessment_limit: 8`. Pass each returned `next_assessment_offset` as
`assessment_offset` to continue on the same revision. Restart from the first
page if the revision changes. The first page follows ledger order. Use the full
response when reviewing all assessments and continue related source trails.

When a compatibility checkout links its Git metadata and build directory to the
moved checkout, the launcher resolves the Git junction's physical repository
before starting a fresh server. Already-running MCP processes keep their original
arguments and tool schema until relaunched. If the connected tools lack
`source_kind`, `oracle_read_source`, `oracle_evidence_rubric` or
`oracle_check_scorecard`, use a fresh local launcher process with the same
request pattern above. For other filesystem aliases, launch from the
checkout that owns the index. Use `oracle_status` before recording a source miss:
a catalog binding failure is unavailable, not evidence missing from the catalog.

If the launcher stalls and the local oracle web server is already running,
use its loopback adapter for the same read-only lookup. Record the transport
failure separately from the catalog result so a successful fallback counts
only once.

```powershell
$Body = @{ name = 'oracle_search_catalog'; arguments = @{ terms = '3762195'; limit = 3 } } |
    ConvertTo-Json -Depth 4 -Compress
Invoke-RestMethod 'http://127.0.0.1:8795/api/oracle' -Method Post -ContentType 'application/json' -Body $Body
```

The sunflower-oil checkpoint recorded zero exact hits across 13 original-source questions at revision 117, matching the preceding 0/14 comparison at that depth. One exact hit across ten later retrieval questions returned a shared oil comparator. A separate claim question found partial evidence. The additions preserve the clinical preparation gap and the specific scope of the primary and cultural records. [Sunflower evidence and source coverage](../1000_see_what_sticks_food/followup/sunflower-executive-nov19-48/README.md).

The shared-collection follow-up found one exact registry hit among seventeen new companion-source questions at revision 120. The ten original bodies were already archived and resumed their existing questions. This pass adds the primary comparisons and links the cod trial registry to the analysis cohort. [Shared collection scope and results](../1000_see_what_sticks_food/followup/shared-sunflower-collections-nov19-49/README.md).


The safflower swallowing checkpoint recorded one claim lead and two exact hits among 25 available source questions at revision 121. Three existing registry files were unavailable by exact ID until their public provenance headers were normalized, so they are outside the rate denominator. The comparator subset had 2/16 strict hits, compared with 1/17 in the preceding shared collection companion batch. Formulation and traditional-source questions had 0/6 and 0/3. These batches sampled different evidence gaps. The new source records prioritize original methods, separate symptom items and preparation grade. [Source depths and open routes](../1000_see_what_sticks_food/followup/safflower-swallowing-nov19-50/README.md).

The official ANZCTR lookup uses a trial-number query on its registry page. The native index accepts this form when the official host and query ID match the document ID. It rejects mismatched trials and lookalike hosts. Revision 124 returned the swallowing skills registration and the cultural safflower publication through exact lookup. Twenty identifiers returned paths and both sampled existing controls preserved match order. [Verified paths](../1000_see_what_sticks_food/followup/safflower-swallowing-nov19-50/oracle-source-verification.tsv).


The strawberry index follow-through recorded zero strict hits across 13 comparable first-pass source questions in the new batch at revision 124. One unavailable exact lookup came from the existing unlabeled 2021 trial summary and stays outside that denominator. The earlier claim, indexes and completed trial lookups are carried forward under existing questions. Revision 126 verifies the eight sampled newly indexed locators. These include the timed-test figure, original indexed terms, the newly registered clinical trial and the separately posted Rett fall adverse-event table. [Exact paths and repeatable review](../1000_see_what_sticks_food/followup/strawberry-falls-index-context-nov19-51/README.md).

The clinical comparator and preparation checkpoint logged 14 new exact-source questions. Three original bodies were available and one local abstract was a partial lead. Ten misses included the date-extract paper, recovered ONDRI manuscript, and the full-text routes for recent clinical articles. Repeat checks on three previously logged identities add no denominator rows. [Source-level lookup outcomes](../1000_see_what_sticks_food/followup/shared-clinical-and-food-methods-nov19-74/oracle-source-verification.tsv).

This checkpoint logged 16 specifically selected older clinical archive lookups with 15 full originals and one abstract. Thirteen independently discovered primary or companion identities missed the existing Oracle catalog. These samples address different retrieval questions. ARO reads continue an existing first-pass question. [Source receipts](../1000_see_what_sticks_food/followup/aro-and-clinical-archives-nov19-75/oracle-source-verification.tsv).

## Pantry expansion round 2 checkpoint

The Round 2 baseline audited all 36 unique ingredients (`1,000` frozen claims) at catalog revision `280` (`39,299` indexed files) before external discovery. All `36 / 36` ingredient-level claim sweeps returned partial local leads (`0 / 36` strict hits) with unresolved Round 2 symptom and preparation gaps, and `620` newly discovered primary PMID/NCT source identifiers were absent from revision `280` (`0 / 620` strict hits) prior to archiving `624` primary source extracts and `66` cultural and conversational records (`209` verified cultural records total). [Round 2 findings](../1000_see_what_sticks_food_round_2/findings.md) · [Round 2 manifest](../1000_see_what_sticks_food_round_2/manifest.md)

## Pantry expansion round 3 checkpoint

The Round 3 baseline audited all 37 unique ingredients (`1,000` frozen claims) at catalog revision `282` (`39,989` indexed files) before external discovery. All `37 / 37` ingredient-level claim sweeps returned partial local leads (`0 / 37` strict hits) with unresolved Round 3 symptom, plant-part, and pantry-expansion preparation gaps, and `725` newly discovered primary PMID/NCT source identifiers were absent from revision `282` (`0 / 725` strict hits) prior to archiving `729` primary source extracts and `86` cultural and conversational records (`295` verified cultural records total). [Round 3 findings](../1000_see_what_sticks_food_round_3/findings.md) · [Round 3 manifest](../1000_see_what_sticks_food_round_3/manifest.md)

## Pantry expansion round 4 checkpoint

The Round 4 baseline audited all 35 unique ingredients (`1,000` frozen claims) at catalog revision `283` (`40,804` indexed files, `0` read errors) before external discovery. All `35 / 35` ingredient-level claim sweeps returned partial local leads (`0 / 35` strict hits) with unresolved Round 4 symptom, plant-part, and pantry-expansion preparation gaps, while `513` newly verified primary PMID/NCT source identifiers had `2 / 513` strict baseline hits (`511 / 513` absent from revision `283`) prior to archiving `514` primary source records (including `222` unique cited Europe PMC / NCBI PMC OA full-text XML verified sources tracked separately in `followup/source-depth.tsv`) and `80` cultural and conversational records (`375` verified cultural records total). [Round 4 findings](../1000_see_what_sticks_food_round_4/findings.md) · [Round 4 manifest](../1000_see_what_sticks_food_round_4/manifest.md)

## Pantry expansion round 5 checkpoint

The Round 5 baseline audited all 37 unique ingredients (`1,000` frozen claims) at catalog revision `284` (`41,398` indexed files, `0` read errors) before external discovery. All `37 / 37` ingredient-level claim sweeps returned partial local leads (`0 / 37` strict hits) with unresolved Round 5 symptom, plant-part, and pantry-expansion preparation gaps, while `462` newly verified primary PMID/NCT source identifiers had `2 / 462` strict baseline hits (`460 / 462` absent from revision `284`) prior to archiving `465` primary source records (including `213` unique cited NCBI PMC OA full-text XML verified sources and `377 / 743` = `50.7%` unique cited files at `original_body_verified` tracked separately in `followup/source-depth.tsv`) and `76` cultural and conversational records (`451` verified cultural records total). [Round 5 findings](../1000_see_what_sticks_food_round_5/findings.md) · [Round 5 manifest](../1000_see_what_sticks_food_round_5/manifest.md)

## Pantry expansion round 6 checkpoint

The Round 6 baseline audited all 35 unique ingredients (`1,000` frozen claims) at catalog revision `285` (`41,939` indexed files, `0` read errors) before external discovery. All `35 / 35` ingredient-level claim sweeps returned partial local leads (`0 / 35` strict hits) with unresolved Round 6 symptom, plant-part, and pantry-expansion preparation gaps, while `470` newly verified primary PMID/NCT source identifiers had `4 / 470` strict baseline hits (`466 / 470` absent from revision `285`) prior to archiving `476` primary source records (including `207` unique cited NCBI PMC OA full-text XML verified sources and `343 / 729` = `47.1%` unique cited files / `2,674 / 4,758` = `56.2%` claim–file edges at `original_body_verified` tracked separately in `followup/source-depth.tsv`) and `81` cultural and conversational records (`532` verified cultural records total). [Round 6 findings](../1000_see_what_sticks_food_round_6/findings.md) · [Round 6 manifest](../1000_see_what_sticks_food_round_6/manifest.md)

## Pantry expansion round 7 checkpoint

The Round 7 baseline audited all 35 unique ingredients (`930` frozen claims, completing all `6,930` claims in the 7-round series) at catalog revision `286` (`42,496` indexed files, `0` read errors) before external discovery. All `35 / 35` ingredient-level claim sweeps returned partial local leads (`0 / 35` strict hits) with unresolved Round 7 symptom, plant-part, and pantry-expansion preparation gaps, while `500` newly verified primary PMID/NCT source identifiers were absent from revision `286` (`0 / 500` strict hits) prior to archiving `500` primary source records (including `211` unique cited NCBI PMC OA full-text XML verified sources and `412 / 859` = `48.0%` unique cited files / `2,756 / 4,982` = `55.3%` claim–file edges at `original_body_verified` tracked separately in `followup/source-depth.tsv`) and `99` cultural and conversational records (`631` verified cultural records total). [Round 7 findings](../1000_see_what_sticks_food_round_7/findings.md) · [Round 7 manifest](../1000_see_what_sticks_food_round_7/manifest.md)
