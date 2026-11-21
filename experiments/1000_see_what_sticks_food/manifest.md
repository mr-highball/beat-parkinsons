# Parkinson's food thought experiment results

Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.

- Frozen SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`
- [Statement verdict ledger](verdicts.tsv)
- [First-pass search ledger](queries.tsv) with 2000 completed records and 1000 statements covered
- [Local file coverage](local-coverage.tsv)
- [Local candidate screening](local-screening.tsv)
- [Counts by category and claim direction](results-summary.tsv)

## Verdict counts

| Verdict | Local review | Current verdict |
| --- | ---: | ---: |
| Unknown | 1000 | 933 |
| Maybe True | 0 | 35 |
| Maybe False | 0 | 32 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

One hundred thirty-two Round 1 claims carry a checked version 1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv), [scorecard-sources.tsv](followup/scorecard-sources.tsv)), covering all 33 Parkinson's symptoms (`26/26` `rest tremor severity` claims audited to `100%` v1 coverage) with zero unscorecarded directional verdicts and zero ledger mismatches. Confidence scores on checked claims denote ordinal review tiers (`50` open, `50.005` minimal signal, `51` limited clinical link, `55` direct clinical signal, `60` strong directional evidence). Across the 132 checked claims, **60 hold directional verdicts (`30` Maybe True, `30` Maybe False) across 15 symptoms** (`2` direct clinical signal, `3` limited clinical link, `55` minimal signal — `59` easing leans and `1` worsening lean), and 72 hold checked `open` (`Unknown`, `50`) scorecards—including 13 legacy `51` claims downgraded on audit, 16 initial zero-directional flagship audits, `0259` (raw orange / falls, linking Sim et al. 2018 and Altemor `PMID:40694049` / `NCT06352099`), 10 Milestone 5 high-assessment deep audits (`0805`, `0147`, `0542`, `0359`, `0979`, `0001`, `0175`, `0758`, `0196`, `0062`), and 14 remaining `rest tremor severity` claims audited under v1 (`0221`, `0234`, `0307`, `0380`, `0403`, `0438`, `0443`, `0627`, `0633`, `0732`, `0833`, `0884`, `0961`, `0986`).

### Highlighted checked v1 findings

- **Ground saffron and Parkinson depression ([0063](statements/0063.txt), Maybe False, 55 — direct clinical signal):** Randomized 92-person Parkinson trial of fixed oral Sargol stigma powder tablets favored lower DASS depression (-4.58 points, 95% CI -8.34 to -0.81), opposing the frozen worsening hypothesis. Independent Tehran trial also favored Hamilton depression with two inconclusive secondary scales.
- **Dried saffron and Parkinson fatigue ([0485](statements/0485.txt), Maybe False, 55 — direct clinical signal):** Same 92-person Parkinson trial favored lower Parkinson Fatigue Scale scores (-9.20 points, 95% CI -13.76 to -4.65); original public registration omitted the standalone fatigue scale until a post-receipt revision, keeping the signal provisional.
- **Brewed black tea and Parkinson bradykinesia ([0082](statements/0082.txt), Maybe True, 51 — limited clinical link):** Double-blind randomized Parkinson caffeine trial (Postuma et al. 2012, `n = 61`) reported lower UPDRS motor/bradykinesia scores on caffeine versus placebo (-4.69 UPDRS-III points), linked to brewed black tea via infusion chromatography; isolated caffeine transfer and longer-term follow-up remain open.
- **Brewed black tea and Parkinson rest tremor ([0904](statements/0904.txt), Maybe True, 51 — limited clinical link):** Parkinson placebo comparison isolates rest tremor with a small favorable isolated-caffeine point estimate (CI spanning zero), linked by chromatography to brewed black tea; open-label mixed responses limit transfer. Complete `26/26` Round 1 `rest tremor severity` audit confirmed `0904` and [0281](statements/0281.txt) (raw celery stalk, `Maybe False`, `50.005`) as the two valid tremor easing leans, while cataloging three newly surfaced rodent tremor/dyskinesia papers (`PMID:22136413` *Murraya koenigii*, `PMID:26217978` quercetin 6-OHDA tremor, `PMID:41354816` / `PMC12797947` quercetin nanoemulsion harmaline tremor).
- **Brewed green tea and Parkinson fatigue ([0948](statements/0948.txt), Maybe True, 51 — limited clinical link):** Uncontrolled 14-completer Parkinson cohort recorded higher mean Fatigue Severity Scale scores (28.4 to 32.1) over three months, contrasting with a postoperative brewed-tea trial outside Parkinson disease.
- **Toasted pumpkin seed oil and Parkinson shortened stride ([0428](statements/0428.txt), Maybe False, 50.005 — minimal signal):** Newly unlocked 14th symptom (Track A audit). Two Parkinson-relevant rodent experiments measured longer stride after oral *Cucurbita pepo* seed extract (`PMID:33759084`, Figure 4: ~6.4, 7.3, 8.0 cm vs 5.7 cm disease control) and oral isolated p-coumaric acid (`DOI:10.1177/0976500X221150837`, `n = 6/group`, `p < 0.05`/`p < 0.01`), bridged by roasting chemistry confirming measurable p-coumaric and ferulic acids in 130–150 °C roasted pressed pumpkin seed oil (`DOI:10.1002/ejlt.201700110`); animal-only gait data and dose equivalence keep the tier minimal.
- **Frozen grape and Parkinson muscle rigidity ([0881](statements/0881.txt), Maybe True, 50.005 — minimal signal):** Newly unlocked 15th symptom (Track A audit). Controlled 6-OHDA MFB-lesioned rat experiment (`PMID:25050252`, `PMC4075680`, `38` Wistar rats across 5 groups of 7–8) reported lower three-stage muscle stiffness/rigidity scores after 28 days of oral hydroalcoholic red grape (*Vitis vinifera*) seed extract (`100 mg/kg/day`) versus untreated and vehicle lesioned controls (`p < 0.01`, Figure 2B); seed-extract versus whole frozen-grape exposure and animal-only rigidity data keep the tier minimal.
- **Grated turmeric and Parkinson olfactory impairment ([0588](statements/0588.txt), Maybe False, 50.005 — minimal signal):** Unlocked 13th symptom (Milestone 5). Two independent 12-week randomized placebo-controlled human trials in renal disease favored oral curcumin capsules over placebo: Nasution et al. 2026 (`PMID:42602430`, `PMC13474629`, `n = 48` hemodialysis RCT; Bonferroni Sniffin' Sticks composite TDI delta `+3.56 p = 0.010` and `+4.00 p = 0.002` vs `+0.875` placebo) and Malekmakan et al. 2023 (`PMID:36967933`, `PMC10031463`, `n = 58` double-blind CKD RCT; QOD `p = 0.045`, self-assessment `p = 0.047`, `20%` vs `0%` normosmia shift `p = 0.032`). Non-Parkinson renal populations and formulated curcumin capsules keep the tier minimal.
- **Ground cinnamon and Parkinson urinary urgency ([0916](statements/0916.txt), Maybe True, 50.005 — minimal signal):** Unlocked 12th symptom. Double-blind randomized overactive-bladder trial (`NCT03532789`, Chen et al. 2020, `n = 66`) favored cinnamon patch over placebo on urgency-frequency (2.82 vs 4.18, p < 0.001) and OABSS (6.33 vs 9.73, p < 0.001), alongside oral mouse cystitis void data (`PMC8716214`); non-Parkinson population and non-oral primary route keep the tier minimal.
- **Extra-virgin olive oil and Parkinson constipation ([0072](statements/0072.txt), Maybe True, 50.005 — minimal signal):** Double-blind randomized trial in 140 analyzed adults with functional constipation (Joukar et al. 2025, `PMC12694839`) favored raw extra-virgin over refined olive oil on Rome III severity (-4.22, p < 0.001) and week-4 Bristol stool form (+1.14, p < 0.001) while excluding neurological disease, lacking an oil-free arm and omitting polyphenol assay. Parkinson Mediterranean diet trials (`MEDI-PD` p = 0.600; `KIM` shared olive oil) did not isolate olive oil.
- **Other minimal-signal leans (50 additional claims at 50.005):** Spanning pain — including newly audited [0956](statements/0956.txt) (ground clove, `PMID:16530911` `n=73` `p=.005` & `PMID:32951708` `n=34` `p=.001`), [0285](statements/0285.txt) (fresh tarragon, `PMID:42866378` `n=90` `p=.001` & `PMID:26170888`), [0312](statements/0312.txt) (cracked black pepper, `DOI:10.15806/j.issn.2311-8571.2015.0032` `n=54` `p<.001` weighed against null oral crossover `PMID:41599836`), [0983](statements/0983.txt) (toasted Sichuan pepper, Bian 2019 dry-fried huajiao `n=50`), and enriched [0812](statements/0812.txt) (ground turmeric, now integrating Soltani et al. 2024 `PMID:39085864` / `PMC11290174` `n=42` double-blind nano-curcumin CSFP RCT favoring SF-36 Bodily Pain `p < 0.001`) — insomnia (newly audited [0140](statements/0140.txt) dried spearmint `PMID:29314866` `N=90` `p=.0046` vs null young-adult trial `PMID:30802720`, and [0256](statements/0256.txt) cold-pressed flaxseed oil `PMID:41478596` `n=68` ISI `p=.029`), anxiety (newly audited [0687](statements/0687.txt) dried cilantro `NCT05999071` `n=86` `p=.04`), urinary urgency (newly audited [0764](statements/0764.txt) fresh shiso `WO2019230626A1` `n=14` `p<.05` & `PMID:29268303`), depression, fatigue, constipation, swallowing difficulty, walking slowness, rest tremor (`0281`) and executive function (full itemized list in [scorecards.tsv](followup/scorecards.tsv)); every directional claim carries an explicit v1 source-family scorecard documenting population, exposure and comparator limits.
- **Downgraded legacy leans and checked `open` audits (72 checked `open` scorecards at 50):** Thirteen legacy `51` claims (`0110`, `0141`, `0168`, `0229`, `0329`, `0340`, `0406`, `0470`, `0513`, `0629`, `0838`, `0874`, `0913`) moved to `Unknown` (`open`) where prior leans rested on unquantified survey tiles, mixed-diet/vitamin-E arms, null contrasts or conflicting reports. Fifty-nine additional checked `open` scorecards document resolved evidence boundaries across the 18 remaining zero-directional symptoms, all 24 non-directional `rest tremor severity` claims, and high-assessment candidates (`0805`, `0147`, `0542`, `0359`, `0979`, `0001`, `0175`, `0758`, `0196`, `0062`).

### Search coverage and limits

- **First-pass baseline:** All 30,593 baseline archive files were read with zero extraction failures ([local-coverage.tsv](local-coverage.tsv)), and 2,000 neutral Europe PMC queries covered all 1,000 frozen statements ([queries.tsv](queries.tsv)).
- **Exact context overlay:** The uncapped original Europe PMC overlay spans 61,252 claim–source pairs across 34,099 source keys (`19,738` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `41,159` queued across `25,911` sources: `0` P1, `0` P2, `12` P3 [all `9/9` sources archived at abstract/citation depth, paywalled], `1,705` P4 [zero Open Access non-homograph pairs remaining; `33` congress-mismatch holds + `38` paywalled non-homograph holds], `2,899` P5, `36,543` P6). Native FPC screening (`foodexperiment.homographscreen` and `foodexperiment.pmcscreen`) cleared `31` archived full-text homograph collisions, reconciled all `19` surfaced unarchived botanical leads ([botanical-triage-leads-nov21](followup/botanical-triage-leads-nov21/README.md)), cleared all `33` Open Access non-homograph Priority-4 full texts ([p4-nonhomograph-fulltext-nov21](followup/p4-nonhomograph-fulltext-nov21/README.md)), and screened all `978` non-homograph Priority-5 pairs (`778` unique PMCIDs retrieved from NCBI PMC JATS XML), reconciling `70` zero-directional-symptom pairs ([p5-zerodir-pmcscreen-nov21](followup/p5-zerodir-pmcscreen-nov21/README.md)) and `178` directional-symptom pairs ([p5-nonhomograph-rest-nov21](followup/p5-nonhomograph-rest-nov21/README.md)). [Context coverage](followup/context-coverage/README.md) · [Study assessments](followup/assessments.tsv)
- **Oracle-to-Nyx web UI auto-sync:** `experiments/tools/parkinsons-oracle/build.ps1` now automatically rebuilds the Nyx web UI (`app.js`, `oracle.css`, glyphs, ingredient gallery, and `graph.json` + `.gz` via auto-discovered local pas2js toolchain) whenever the Oracle or catalog refreshes unless `-SkipWeb` is passed, keeping the public browser graph locked to the committed revision.
- **Cross-round transfer readiness (Rounds 2–7):** Native FPC `foodexperiment.roundtransfer` (`8/8` checked tests) verified all six expansion freezes (`5,930` claims, zero cross-round duplicates) and mapped `4,016 / 5,930` (`67.7%`) expansion claims—including `736 / 1,000` (`73.6%`) of Round 2—to existing Round 1 directional scorecards, study assessments, or matrix-distinct siblings. [Transfer readiness](followup/round-transfer-readiness-nov21/README.md)
- **Active clinical trials monitored (live ClinicalTrials.gov v2 check 2026-11-21):** Ginger-PD (`NCT07882108`, `RECRUITING`, `hasResults=false`, last updated `2026-10-21`), NUTRI-GUT-PD (`NCT07213856`, `RECRUITING`, `hasResults=false`, last updated `2026-06-16`), PRIME (`NCT07097103`, `NOT_YET_RECRUITING`, `hasResults=false`, last updated `2026-07-30`), Grape Powder (`NCT07214428`, `ACTIVE_NOT_RECRUITING`, `hasResults=false`, last updated `2026-08-11`), plus `UMIN000055134`.
- **Historical checkpoint archive:** The complete chronological log of checkpoints through P156 is preserved verbatim in [followup/checkpoint-log.md](followup/checkpoint-log.md).

## Directional verdicts

- [0019](statements/0019.txt) **Maybe True** (50.005%) Consuming toasted nigella seed reduces depressive symptom severity in people with Parkinson's disease.
- [0025](statements/0025.txt) **Maybe False** (50.005%) Consuming fresh sage worsens pain severity in people with Parkinson's disease.
- [0039](statements/0039.txt) **Maybe False** (50.005%) Consuming cold-pressed sesame oil worsens anxiety severity in people with Parkinson's disease.
- [0060](statements/0060.txt) **Maybe False** (50.005%) Consuming dried sage worsens insomnia severity in people with Parkinson's disease.
- [0063](statements/0063.txt) **Maybe False** (55%) Consuming ground saffron worsens depressive symptom severity in people with Parkinson's disease.
- [0065](statements/0065.txt) **Maybe True** (50.005%) Consuming cold-pressed walnut oil reduces pain severity in people with Parkinson's disease.
- [0072](statements/0072.txt) **Maybe True** (50.005%) Consuming extra-virgin olive oil reduces constipation severity in people with Parkinson's disease.
- [0082](statements/0082.txt) **Maybe True** (51%) Consuming brewed black tea reduces bradykinesia severity in people with Parkinson's disease.
- [0100](statements/0100.txt) **Maybe False** (50.005%) Consuming plain dark chocolate worsens anxiety severity in people with Parkinson's disease.
- [0117](statements/0117.txt) **Maybe True** (50.005%) Consuming ground sichuan pepper reduces fatigue severity in people with Parkinson's disease.
- [0121](statements/0121.txt) **Maybe False** (50.005%) Consuming brewed coffee worsens fatigue severity in people with Parkinson's disease.
- [0128](statements/0128.txt) **Maybe False** (50.005%) Consuming fresh rosemary worsens depressive symptom severity in people with Parkinson's disease.
- [0133](statements/0133.txt) **Maybe True** (50.005%) Consuming brewed lemon balm reduces depressive symptom severity in people with Parkinson's disease.
- [0139](statements/0139.txt) **Maybe False** (50.005%) Consuming ground nigella seed worsens fatigue severity in people with Parkinson's disease.
- [0140](statements/0140.txt) **Maybe True** (50.005%) Consuming dried spearmint reduces insomnia severity in people with Parkinson's disease.
- [0144](statements/0144.txt) **Maybe True** (50.005%) Consuming toasted sesame oil reduces pain severity in people with Parkinson's disease.
- [0161](statements/0161.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces pain severity in people with Parkinson's disease.
- [0171](statements/0171.txt) **Maybe False** (50.005%) Consuming toasted fennel seed worsens fatigue severity in people with Parkinson's disease.
- [0180](statements/0180.txt) **Maybe False** (50.005%) Consuming ground nigella seed worsens insomnia severity in people with Parkinson's disease.
- [0181](statements/0181.txt) **Maybe False** (50.005%) Consuming dried cherry worsens fatigue severity in people with Parkinson's disease.
- [0199](statements/0199.txt) **Maybe False** (50.005%) Consuming ground anise seed worsens pain severity in people with Parkinson's disease.
- [0210](statements/0210.txt) **Maybe False** (50.005%) Consuming ground sumac worsens constipation severity in people with Parkinson's disease.
- [0218](statements/0218.txt) **Maybe True** (50.005%) Consuming ground saffron reduces insomnia severity in people with Parkinson's disease.
- [0225](statements/0225.txt) **Maybe True** (50.005%) Consuming grated turmeric reduces swallowing difficulty severity in people with Parkinson's disease.
- [0256](statements/0256.txt) **Maybe True** (50.005%) Consuming cold-pressed flaxseed oil reduces insomnia severity in people with Parkinson's disease.
- [0262](statements/0262.txt) **Maybe True** (50.005%) Consuming cold-pressed sesame oil reduces depressive symptom severity in people with Parkinson's disease.
- [0267](statements/0267.txt) **Maybe False** (50.005%) Consuming refined sunflower oil worsens swallowing difficulty severity in people with Parkinson's disease.
- [0277](statements/0277.txt) **Maybe False** (50.005%) Consuming ground anise seed worsens fatigue severity in people with Parkinson's disease.
- [0281](statements/0281.txt) **Maybe False** (50.005%) Consuming raw celery stalk worsens rest tremor severity in people with Parkinson's disease.
- [0285](statements/0285.txt) **Maybe True** (50.005%) Consuming fresh tarragon reduces pain severity in people with Parkinson's disease.
- [0309](statements/0309.txt) **Maybe False** (50.005%) Consuming raw banana worsens anxiety severity in people with Parkinson's disease.
- [0312](statements/0312.txt) **Maybe False** (50.005%) Consuming cracked black pepper worsens pain severity in people with Parkinson's disease.
- [0327](statements/0327.txt) **Maybe True** (50.005%) Consuming ground cayenne pepper reduces dystonia severity in people with Parkinson's disease.
- [0343](statements/0343.txt) **Maybe True** (50.005%) Consuming cold-pressed olive oil reduces anxiety severity in people with Parkinson's disease.
- [0348](statements/0348.txt) **Maybe True** (50.005%) Consuming poached chicken reduces fatigue severity in people with Parkinson's disease.
- [0362](statements/0362.txt) **Maybe True** (50.005%) Consuming dried thyme reduces anxiety severity in people with Parkinson's disease.
- [0404](statements/0404.txt) **Maybe False** (50.005%) Consuming cold-pressed sesame oil worsens fatigue severity in people with Parkinson's disease.
- [0428](statements/0428.txt) **Maybe False** (50.005%) Consuming toasted pumpkin seed oil worsens shortened stride severity in people with Parkinson's disease.
- [0485](statements/0485.txt) **Maybe False** (55%) Consuming dried saffron worsens fatigue severity in people with Parkinson's disease.
- [0507](statements/0507.txt) **Maybe True** (50.005%) Consuming ground turmeric reduces bradykinesia severity in people with Parkinson's disease.
- [0560](statements/0560.txt) **Maybe True** (50.005%) Consuming ground cumin reduces constipation severity in people with Parkinson's disease.
- [0581](statements/0581.txt) **Maybe False** (50.005%) Consuming grated ginger worsens constipation severity in people with Parkinson's disease.
- [0588](statements/0588.txt) **Maybe False** (50.005%) Consuming grated turmeric worsens olfactory impairment severity in people with Parkinson's disease.
- [0639](statements/0639.txt) **Maybe True** (50.005%) Consuming cold-pressed flaxseed oil reduces pain severity in people with Parkinson's disease.
- [0642](statements/0642.txt) **Maybe False** (50.005%) Consuming grated turmeric worsens walking slowness in people with Parkinson's disease.
- [0659](statements/0659.txt) **Maybe True** (50.005%) Consuming fresh summer savory reduces pain severity in people with Parkinson's disease.
- [0663](statements/0663.txt) **Maybe True** (50.005%) Consuming poached salmon reduces anxiety severity in people with Parkinson's disease.
- [0687](statements/0687.txt) **Maybe True** (50.005%) Consuming dried cilantro reduces anxiety severity in people with Parkinson's disease.
- [0725](statements/0725.txt) **Maybe True** (50.005%) Consuming grated ginger reduces pain severity in people with Parkinson's disease.
- [0746](statements/0746.txt) **Maybe True** (50.005%) Consuming raw blueberry reduces constipation severity in people with Parkinson's disease.
- [0764](statements/0764.txt) **Maybe False** (50.005%) Consuming fresh shiso worsens urinary urgency frequency in people with Parkinson's disease.
- [0810](statements/0810.txt) **Maybe True** (50.005%) Consuming raw cantaloupe reduces fatigue severity in people with Parkinson's disease.
- [0812](statements/0812.txt) **Maybe True** (50.005%) Consuming ground turmeric reduces pain severity in people with Parkinson's disease.
- [0814](statements/0814.txt) **Maybe True** (50.005%) Consuming fresh basil reduces insomnia severity in people with Parkinson's disease.
- [0836](statements/0836.txt) **Maybe False** (50.005%) Consuming toasted sichuan pepper worsens attention impairment in people with Parkinson's disease.
- [0860](statements/0860.txt) **Maybe False** (50.005%) Consuming raw grape worsens anxiety severity in people with Parkinson's disease.
- [0878](statements/0878.txt) **Maybe False** (50.005%) Consuming raw orange worsens constipation severity in people with Parkinson's disease.
- [0881](statements/0881.txt) **Maybe True** (50.005%) Consuming frozen grape reduces muscle rigidity severity in people with Parkinson's disease.
- [0883](statements/0883.txt) **Maybe False** (50.005%) Consuming fresh sage worsens fatigue severity in people with Parkinson's disease.
- [0889](statements/0889.txt) **Maybe False** (50.005%) Consuming ground cinnamon worsens walking slowness in people with Parkinson's disease.
- [0904](statements/0904.txt) **Maybe True** (51%) Consuming brewed black tea reduces rest tremor severity in people with Parkinson's disease.
- [0916](statements/0916.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces urinary urgency frequency in people with Parkinson's disease.
- [0948](statements/0948.txt) **Maybe True** (51%) Consuming brewed green tea worsens fatigue severity in people with Parkinson's disease.
- [0949](statements/0949.txt) **Maybe False** (50.005%) Consuming frozen raspberry worsens executive function impairment in people with Parkinson's disease.
- [0953](statements/0953.txt) **Maybe False** (50.005%) Consuming boiled barley worsens anxiety severity in people with Parkinson's disease.
- [0956](statements/0956.txt) **Maybe True** (50.005%) Consuming ground clove reduces pain severity in people with Parkinson's disease.
- [0983](statements/0983.txt) **Maybe True** (50.005%) Consuming toasted sichuan pepper reduces pain severity in people with Parkinson's disease.
