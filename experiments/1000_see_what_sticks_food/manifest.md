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
| Unknown | 1000 | 950 |
| Maybe True | 0 | 23 |
| Maybe False | 0 | 27 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

Ninety-seven Round 1 claims carry a checked version 1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv), [scorecard-sources.tsv](followup/scorecard-sources.tsv)), covering all 33 Parkinson's symptoms with zero unscorecarded directional verdicts and zero ledger mismatches. Confidence scores on checked claims denote ordinal review tiers (`50` open, `50.005` minimal signal, `51` limited clinical link, `55` direct clinical signal, `60` strong directional evidence). Across the 97 checked claims, 49 hold directional verdicts (`23` Maybe True, `26` Maybe False) across 12 symptoms (`2` direct clinical signal, `3` limited clinical link, `44` minimal signal), and 48 hold checked `open` (`Unknown`, `50`) scorecards—including 13 legacy `51` claims downgraded on audit, 16 zero-directional symptom flagship audits, and `0259` (raw orange / falls, linking the null Sim et al. 2018 citrus cohort and the multi-ingredient Altemor pilot `PMID:40694049` / `NCT06352099`).

### Highlighted checked v1 findings

- **Ground saffron and Parkinson depression ([0063](statements/0063.txt), Maybe False, 55 — direct clinical signal):** Randomized 92-person Parkinson trial of fixed oral Sargol stigma powder tablets favored lower DASS depression (-4.58 points, 95% CI -8.34 to -0.81), opposing the frozen worsening hypothesis. Independent Tehran trial also favored Hamilton depression with two inconclusive secondary scales.
- **Dried saffron and Parkinson fatigue ([0485](statements/0485.txt), Maybe False, 55 — direct clinical signal):** Same 92-person Parkinson trial favored lower Parkinson Fatigue Scale scores (-9.20 points, 95% CI -13.76 to -4.65); original public registration omitted the standalone fatigue scale until a post-receipt revision, keeping the signal provisional.
- **Brewed black tea and Parkinson bradykinesia ([0082](statements/0082.txt), Maybe True, 51 — limited clinical link):** Double-blind randomized Parkinson caffeine trial (Postuma et al. 2012, `n = 61`) reported lower UPDRS motor/bradykinesia scores on caffeine versus placebo (-4.69 UPDRS-III points), linked to brewed black tea via infusion chromatography; isolated caffeine transfer and longer-term follow-up remain open.
- **Brewed black tea and Parkinson rest tremor ([0904](statements/0904.txt), Maybe True, 51 — limited clinical link):** Parkinson placebo comparison isolates rest tremor with a small favorable isolated-caffeine point estimate (CI spanning zero), linked by chromatography to brewed black tea; open-label mixed responses limit transfer.
- **Brewed green tea and Parkinson fatigue ([0948](statements/0948.txt), Maybe True, 51 — limited clinical link):** Uncontrolled 14-completer Parkinson cohort recorded higher mean Fatigue Severity Scale scores (28.4 to 32.1) over three months, contrasting with a postoperative brewed-tea trial outside Parkinson disease.
- **Ground cinnamon and Parkinson urinary urgency ([0916](statements/0916.txt), Maybe True, 50.005 — minimal signal):** Newly unlocked symptom. Double-blind randomized overactive-bladder trial (`NCT03532789`, Chen et al. 2020, `n = 66`) favored cinnamon patch over placebo on urgency-frequency (2.82 vs 4.18, p < 0.001) and OABSS (6.33 vs 9.73, p < 0.001), alongside oral mouse cystitis void data (`PMC8716214`); non-Parkinson population and non-oral primary route keep the tier minimal.
- **Extra-virgin olive oil and Parkinson constipation ([0072](statements/0072.txt), Maybe True, 50.005 — minimal signal):** Double-blind randomized trial in 140 analyzed adults with functional constipation (Joukar et al. 2025, `PMC12694839`) favored raw extra-virgin over refined olive oil on Rome III severity (-4.22, p < 0.001) and week-4 Bristol stool form (+1.14, p < 0.001) while excluding neurological disease, lacking an oil-free arm and omitting polyphenol assay. Parkinson Mediterranean diet trials (`MEDI-PD` p = 0.600; `KIM` shared olive oil) did not isolate olive oil.
- **Other minimal-signal leans (42 additional claims at 50.005):** Spanning pain, anxiety, depression, fatigue, insomnia, constipation, swallowing difficulty, walking slowness and executive function (full itemized list below and in [scorecards.tsv](followup/scorecards.tsv)); every directional claim now carries an explicit v1 source-family scorecard documenting population, exposure and comparator limits.
- **Downgraded legacy leans and zero-directional symptom audits (47 checked `open` scorecards at 50):** Thirteen legacy `51` claims (`0110`, `0141`, `0168`, `0229`, `0329`, `0340`, `0406`, `0470`, `0513`, `0629`, `0838`, `0874`, `0913`) moved to `Unknown` (`open`) where prior leans rested on unquantified survey tiles, mixed-diet/vitamin-E arms, null contrasts or conflicting reports. Sixteen flagship zero-directional symptom audits (`0020`, `0024`, `0030`, `0047`, `0126`, `0271`, `0417`, `0432`, `0447`, `0482`, `0491`, `0535`, `0712`, `0760`, `0796`, `0952`) document open evidence gaps across the remaining symptoms without directional evidence.

### Search coverage and limits

- **First-pass baseline:** All 30,593 baseline archive files were read with zero extraction failures ([local-coverage.tsv](local-coverage.tsv)), and 2,000 neutral Europe PMC queries covered all 1,000 frozen statements ([queries.tsv](queries.tsv)).
- **Exact context overlay:** The uncapped original Europe PMC overlay spans 61,252 claim–source pairs across 34,099 source keys (`19,490` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `41,407` queued across `26,005` sources: `0` P1, `0` P2, `12` P3 [all `9/9` sources archived at abstract/citation depth, paywalled], `1,705` P4 [zero Open Access non-homograph pairs remaining; `33` congress-mismatch holds + `38` paywalled non-homograph holds], `3,147` P5, `36,543` P6). Native FPC screening cleared `31` archived full-text homograph collisions, reconciled all `19` surfaced unarchived botanical leads ([botanical-triage-leads-nov21](followup/botanical-triage-leads-nov21/README.md)), and cleared all `33` Open Access non-homograph Priority-4 full texts ([p4-nonhomograph-fulltext-nov21](followup/p4-nonhomograph-fulltext-nov21/README.md)). [Context coverage](followup/context-coverage/README.md) · [Study assessments](followup/assessments.tsv)
- **Cross-round transfer readiness (Rounds 2–7):** Native FPC `foodexperiment.roundtransfer` (`8/8` checked tests) verified all six expansion freezes (`5,930` claims, zero cross-round duplicates) and mapped `4,016 / 5,930` (`67.7%`) expansion claims—including `736 / 1,000` (`73.6%`) of Round 2—to existing Round 1 directional scorecards, study assessments, or matrix-distinct siblings. [Transfer readiness](followup/round-transfer-readiness-nov21/README.md)
- **Active clinical trials to monitor:** Ginger-PD (`NCT07882108`, pain/GI), NUTRI-GUT-PD (`NCT07213856`, constipation/gut), PRIME (`NCT07097103`), plus pending registry records (`NCT07214428`, `UMIN000055134`).
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
- [0121](statements/0121.txt) **Maybe False** (50.005%) Consuming brewed coffee worsens fatigue severity in people with Parkinson's disease.
- [0128](statements/0128.txt) **Maybe False** (50.005%) Consuming fresh rosemary worsens depressive symptom severity in people with Parkinson's disease.
- [0133](statements/0133.txt) **Maybe True** (50.005%) Consuming brewed lemon balm reduces depressive symptom severity in people with Parkinson's disease.
- [0139](statements/0139.txt) **Maybe False** (50.005%) Consuming ground nigella seed worsens fatigue severity in people with Parkinson's disease.
- [0144](statements/0144.txt) **Maybe True** (50.005%) Consuming toasted sesame oil reduces pain severity in people with Parkinson's disease.
- [0161](statements/0161.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces pain severity in people with Parkinson's disease.
- [0171](statements/0171.txt) **Maybe False** (50.005%) Consuming toasted fennel seed worsens fatigue severity in people with Parkinson's disease.
- [0180](statements/0180.txt) **Maybe False** (50.005%) Consuming ground nigella seed worsens insomnia severity in people with Parkinson's disease.
- [0181](statements/0181.txt) **Maybe False** (50.005%) Consuming dried cherry worsens fatigue severity in people with Parkinson's disease.
- [0199](statements/0199.txt) **Maybe False** (50.005%) Consuming ground anise seed worsens pain severity in people with Parkinson's disease.
- [0218](statements/0218.txt) **Maybe True** (50.005%) Consuming ground saffron reduces insomnia severity in people with Parkinson's disease.
- [0225](statements/0225.txt) **Maybe True** (50.005%) Consuming grated turmeric reduces swallowing difficulty severity in people with Parkinson's disease.
- [0262](statements/0262.txt) **Maybe True** (50.005%) Consuming cold-pressed sesame oil reduces depressive symptom severity in people with Parkinson's disease.
- [0267](statements/0267.txt) **Maybe False** (50.005%) Consuming refined sunflower oil worsens swallowing difficulty severity in people with Parkinson's disease.
- [0277](statements/0277.txt) **Maybe False** (50.005%) Consuming ground anise seed worsens fatigue severity in people with Parkinson's disease.
- [0281](statements/0281.txt) **Maybe False** (50.005%) Consuming raw celery stalk worsens rest tremor severity in people with Parkinson's disease.
- [0309](statements/0309.txt) **Maybe False** (50.005%) Consuming raw banana worsens anxiety severity in people with Parkinson's disease.
- [0343](statements/0343.txt) **Maybe True** (50.005%) Consuming cold-pressed olive oil reduces anxiety severity in people with Parkinson's disease.
- [0362](statements/0362.txt) **Maybe True** (50.005%) Consuming dried thyme reduces anxiety severity in people with Parkinson's disease.
- [0404](statements/0404.txt) **Maybe False** (50.005%) Consuming cold-pressed sesame oil worsens fatigue severity in people with Parkinson's disease.
- [0485](statements/0485.txt) **Maybe False** (55%) Consuming dried saffron worsens fatigue severity in people with Parkinson's disease.
- [0560](statements/0560.txt) **Maybe True** (50.005%) Consuming ground cumin reduces constipation severity in people with Parkinson's disease.
- [0581](statements/0581.txt) **Maybe False** (50.005%) Consuming grated ginger worsens constipation severity in people with Parkinson's disease.
- [0588](statements/0588.txt) **Maybe False** (50.005%) Consuming grated turmeric worsens olfactory impairment severity in people with Parkinson's disease.
- [0639](statements/0639.txt) **Maybe True** (50.005%) Consuming cold-pressed flaxseed oil reduces pain severity in people with Parkinson's disease.
- [0642](statements/0642.txt) **Maybe False** (50.005%) Consuming grated turmeric worsens walking slowness in people with Parkinson's disease.
- [0659](statements/0659.txt) **Maybe True** (50.005%) Consuming fresh summer savory reduces pain severity in people with Parkinson's disease.
- [0663](statements/0663.txt) **Maybe True** (50.005%) Consuming poached salmon reduces anxiety severity in people with Parkinson's disease.
- [0725](statements/0725.txt) **Maybe True** (50.005%) Consuming grated ginger reduces pain severity in people with Parkinson's disease.
- [0746](statements/0746.txt) **Maybe True** (50.005%) Consuming raw blueberry reduces constipation severity in people with Parkinson's disease.
- [0812](statements/0812.txt) **Maybe True** (50.005%) Consuming ground turmeric reduces pain severity in people with Parkinson's disease.
- [0814](statements/0814.txt) **Maybe True** (50.005%) Consuming fresh basil reduces insomnia severity in people with Parkinson's disease.
- [0860](statements/0860.txt) **Maybe False** (50.005%) Consuming raw grape worsens anxiety severity in people with Parkinson's disease.
- [0878](statements/0878.txt) **Maybe False** (50.005%) Consuming raw orange worsens constipation severity in people with Parkinson's disease.
- [0883](statements/0883.txt) **Maybe False** (50.005%) Consuming fresh sage worsens fatigue severity in people with Parkinson's disease.
- [0889](statements/0889.txt) **Maybe False** (50.005%) Consuming ground cinnamon worsens walking slowness in people with Parkinson's disease.
- [0904](statements/0904.txt) **Maybe True** (51%) Consuming brewed black tea reduces rest tremor severity in people with Parkinson's disease.
- [0916](statements/0916.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces urinary urgency frequency in people with Parkinson's disease.
- [0948](statements/0948.txt) **Maybe True** (51%) Consuming brewed green tea worsens fatigue severity in people with Parkinson's disease.
- [0949](statements/0949.txt) **Maybe False** (50.005%) Consuming frozen raspberry worsens executive function impairment in people with Parkinson's disease.
- [0953](statements/0953.txt) **Maybe False** (50.005%) Consuming boiled barley worsens anxiety severity in people with Parkinson's disease.
