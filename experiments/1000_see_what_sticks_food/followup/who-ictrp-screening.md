# WHO ICTRP Parkinson registry screening

WHO ICTRP processed the public basic `Parkinson` export on November 12, 2026 at 09:13:15, as reported in its `Export_date` field. The 26,556,496-byte XML has SHA-256 `ABEF724E5EC9879416EB8785DE4B1489FA0FC9B2CA89D445734AF74779B9DA9A`. The native screen reconciled 4,471 XML records against the portal count and verified 4,471 unique TrialIDs and internal record numbers. The export spans 18 providers, with 3,054 ClinicalTrials.gov records and 1,417 from other providers. [WHO data terms](https://www.who.int/tools/clinical-trials-registry-platform/network/who-data-set/downloading-records-from-the-ictrp-database) · [Public search retrieval and alternate expressions](who-ictrp-export-audit.md)

## Candidate coverage

| Snapshot | Export rows | Rows new to the main search | Exposure flags in new rows | Individually documented dispositions |
| --- | ---: | ---: | ---: | --- |
| `Parkinson` | 4,471 | 4,471 | 324 | 112 of 112 outside ClinicalTrials.gov. [ClinicalTrials.gov crosswalk audit](who-ictrp-ctg-audit.md) |
| `Parkinsonism` | 331 | 209 | 22 | 22 of 22 |
| Quoted `"Parkinson disease"` | 3,302 | 0 | 0 | No additional TrialIDs |

The 4,680 unique TrialIDs across the three snapshots provide registry discovery coverage for these expressions. The main export supplied 112 exposure flags outside ClinicalTrials.gov and 212 from ClinicalTrials.gov. The 112 non-ClinicalTrials.gov flags comprise 20 ingredient-name or related-exposure flags, 46 broad food-term flags and 46 contextual flags. Each has an individual ledger disposition. The contextual matches include eligibility restrictions, habitual intake held constant, and two Thai drug trials with egg as a common diagnostic stimulus or an allergy exclusion. Of the broad food-term flags, follow-up found results for reishi extract with endurance exercise, probiotic and vitamin D capsules, B12 and folate, and yokukansan. These comparisons did not measure the effect of a frozen culinary preparation on its specified outcome. [Screened records](who-ictrp-dispositions.tsv) · [2020–2024 findings](../../../research/2020-2024/Food-Experiment-WHO-ICTRP-Followup.md) · [2010–2014 findings](../../../research/2010-2014/Food-Experiment-WHO-ICTRP-Followup.md)

The existing native matcher checks frozen ingredient names and aliases, related constituents, and broader dietary and botanical terms. It assigns the most specific match to public title, scientific title or intervention and flags ingredient mentions in conditions, eligibility and outcomes separately. The Parkinson wording flag distinguishes title or condition from other fields and exclusions. Both flags need human verification. Examples include calendar dates, a drug manufacturer called SAGE, colored cones, assessment instructions, and geographic terms that happen to be food names. Language and field availability vary by provider. Results can also reside only in a primary registry, paper or conference abstract.

## Accession grouping

The parser keeps each reported TrialID in its original row and outputs evidence for connected accession groups separately. Exact TrialID references and recognized registry accessions in semicolon-delimited secondary IDs produce edges. The parser normalizes known provider prefixes and the country suffix of an EUCTR accession. Sponsor codes and title similarity do not establish links.

There are 4,442 provisional accession groups in the main snapshot, including 25 multi-row groups spanning 54 records. The 31 evidence edges comprise direct references to a primary ID and shared formal secondary accessions. A connected group can contain conflicting cross-references. The five-row group anchored by CTRI/2012/07/002811 links records with two different EU accessions and two different cited NCT numbers. Its records remain separately addressable. WHO marks 207 records as having other records, 191 of them without an in-export accession group under this rule. Provider flags, export omissions and ambiguous cross-references limit deduplication.

## Verified outcome and registry leads

- Kashikar and Rao linked CTRI/2018/09/015592 to a 2019 uncontrolled parkinsonism series. The regimen included processed rectal sesame oil, other enemas and a purgative. The paper gives favorable within-person gait, speech and facial-expression scores. The regimen and measures leave the culinary sesame oil claims unresolved. The publisher PDF was inspected with a one-off `pdfplumber` text extraction and Poppler page rendering in the local build directory. [Dated evidence](../../../research/2015-2019/Food-Experiment-WHO-ICTRP-Followup.md#rectal-botanical-regimen-containing-sesame-oil)
- CTRI/2022/06/043208 links the 2023 marigold supplement trial. Both arms used coconut-derived MCT oil. Counts from the published patient table show global cognitive improvement in four of eight Parkinson-only participants receiving extract and zero of six receiving the MCT comparator. An executive-domain result and an isolated coconut oil contrast are unavailable. [Dated evidence](../../../research/2020-2024/Food-Experiment-WHO-ICTRP-Followup.md#coconut-derived-mct-as-a-carrier-in-a-marigold-extract-trial)
- CTRI/2026/02/102865 registers a botanical combination with black pepper, ginger and cinnamon, and an unspecified celery species preparation. The public export gives a 12-week motor composite and no outcomes. The first-party CTRI endpoint timed out on review. [Dated registry note](../../../research/2025-2029/Food-Experiment-WHO-ICTRP-Followup.md#habb-e-ishrat-combination-and-motor-outcomes)
- The `Parkinsonism` supplement exposed ChiCTR1900023725, a separate pharmaceutical butylphthalide trial with diagnosis-specific arms and 48-week follow-up. The primary page returned HTTP 405 to the browser service, and exact accession, investigator and grant searches gave no linked outcome report. [Dated registry note](../../../research/2015-2019/Food-Experiment-WHO-ICTRP-Followup.md#pharmaceutical-butylphthalide-across-parkinsonian-diagnoses)
- The primary Dutch registry and October 2026 conference design report verify the 236-person Plants for Parkinson dietary-pattern study, with six months of guided intervention and six months of follow-up. The Thai registry separately gives a Mediterranean cooking workshop and a completed 12-person effervescent velvet bean pilot without results. The vitamin D trial has published inconclusive motor and cognitive comparisons. [Dated records](../../../research/2025-2029/Food-Experiment-WHO-ICTRP-Followup.md)

## Reproduce the local screen

From the repository root, point the parser at the official saved XML and the public result count. WHO ICTRP asks users who publish or distribute the underlying data to give the source and processing date, keep the data current, and avoid commercial use. The raw exports and generated full-record candidate views are retained locally under the ignored `build` directory. [WHO data terms](https://www.who.int/tools/clinical-trials-registry-platform/network/who-data-set/downloading-records-from-the-ictrp-database)

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$exe = & "$experiment/tools/build-who-ictrp.ps1" | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$work = "$experiment/build/who-ictrp"
& $exe $experiment "$work/parkinson-export-all.bin" "$work/screen" 4471
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $exe $experiment "$work/parkinsonism-export-all.bin" "$work/parkinsonism-screen" 331
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $exe $experiment "$work/exact-parkinson-disease-export-all.bin" "$work/exact-parkinson-disease-screen" 3302
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

The generated inventory has one row per trial. The candidates file has one row per flagged trial with separate name, constituent, broad food and contextual fields. The bridges file records each accession edge. The provider counts file gives export date, rows, candidate rows and bridging counts. FPC 3.3.1 compiled with assertions and range, overflow and I/O checks. A deliberate mismatch of 4,470 expected rows exited before creating output, and the repeat run matched all four files byte for byte. [Parser](../tools/foodexperiment.whoictrp.lpr) · [Build script](../tools/build-who-ictrp.ps1)
