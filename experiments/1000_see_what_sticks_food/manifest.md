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
| Unknown | 1000 | 929 |
| Maybe True | 0 | 38 |
| Maybe False | 0 | 33 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

All 1,000 frozen Round 1 claims have a v1 evidence scorecard with 3,808 source-family rows. Round 1 now records 71 directional verdicts (38 Maybe True and 33 Maybe False) across 18 symptoms and 929 open verdicts. There are 69 easing leans and two worsening leans, with 2 direct clinical signals, 3 limited clinical links and 66 minimal signals. Research-status rows document completed checks and open gaps. The original-source queue, deeper searches and independent direction audit remain open. [Scorecards](followup/scorecards.tsv) · [Research status](followup/research-status.tsv) · [Direction audit](followup/direction-bias-audit-nov21/README.md) · [Dietary protein follow-up](followup/protein-levodopa-audit-nov22/README.md) · [Caffeine and tea follow-up](followup/caffeine-and-tea-originals-nov22/README.md)

### Highlighted checked v1 findings

The sage audit verified 48 original claim–source pairs across five frozen hypotheses and recorded 20 remaining access gaps in dated local source text. The Round 1 queue now holds 40,372 pairs across 25,621 source keys. All five scorecards retain their prior verdicts. [Sage originals and gaps](followup/sage-originals-nov22/README.md)

The UEG and hematology originals resolved 61 source pairs. One UEG abstract led to the full TANDIM trial and its same-cohort analysis. Both olive-oil scorecards retain their 50.005 easing grade after the whole-diet constipation comparison and the oil-specific anxiety recheck. [Open congress originals and TANDIM](followup/open-congress-originals-nov22/README.md)

The November 22 indexed-primary audit moved 17 source reviews to original-body depth for the raw-orange and fall-frequency claim. Verified source matches concerned other exposures, endpoints, places or figure labels. At that checkpoint, 40,481 exact pairs remained. [Indexed originals and remaining gaps](followup/indexed-primary-originals-nov22/README.md)

- **Ground saffron and Parkinson depression ([0063](statements/0063.txt), Maybe False, 55 — direct clinical signal):** Randomized 92-person Parkinson trial of fixed oral Sargol stigma powder tablets favored lower DASS depression (-4.58 points, 95% CI -8.34 to -0.81), opposing the frozen worsening hypothesis. Independent Tehran trial also favored Hamilton depression with two inconclusive secondary scales.
- **Dried saffron and Parkinson fatigue ([0485](statements/0485.txt), Maybe False, 55 — direct clinical signal):** Same 92-person Parkinson trial favored lower Parkinson Fatigue Scale scores (-9.20 points, 95% CI -13.76 to -4.65); original public registration omitted the standalone fatigue scale until a post-receipt revision, keeping the signal provisional.
- **Brewed black tea and Parkinson bradykinesia ([0082](statements/0082.txt), Maybe True, 51 — limited clinical link):** Double-blind randomized Parkinson caffeine trial (Postuma et al. 2012, `n = 61`) reported lower UPDRS motor/bradykinesia scores on caffeine versus placebo (-4.69 UPDRS-III points), linked to brewed black tea via infusion chromatography; isolated caffeine transfer and longer-term follow-up remain open.
- **Brewed black tea and Parkinson rest tremor ([0904](statements/0904.txt), Maybe True, 51 — limited clinical link):** Parkinson placebo comparison isolates rest tremor with a small favorable isolated-caffeine point estimate (CI spanning zero), linked by chromatography to brewed black tea; open-label mixed responses limit transfer. Complete `26/26` Round 1 `rest tremor severity` audit confirmed `0904` and [0281](statements/0281.txt) (raw celery stalk, `Maybe False`, `50.005`) as the two valid tremor easing leans, while cataloging three newly surfaced rodent tremor/dyskinesia papers (`PMID:22136413` *Murraya koenigii*, `PMID:26217978` quercetin 6-OHDA tremor, `PMID:41354816` / `PMC12797947` quercetin nanoemulsion harmaline tremor).
- **Brewed green tea and Parkinson fatigue ([0948](statements/0948.txt), Maybe True, 51 — limited clinical link):** Uncontrolled 14-completer Parkinson cohort recorded higher mean Fatigue Severity Scale scores (28.4 to 32.1) over three months, contrasting with a postoperative brewed-tea trial outside Parkinson disease.
- **Toasted Sichuan pepper and Parkinson attention impairment ([0836](statements/0836.txt), Maybe False, 50.005 — minimal signal):** Newly unlocked 16th symptom (Phase 2 deep audit). Double-blind randomized placebo-controlled trial in 82 healthy adults aged 30–55 (Kennedy 2019, `PMID:31835620`, `PMC6950039`, `NCT03673930`) reported faster acute Speed of Attention (`p = .039`) and fewer rapid visual information processing false alarms (`p = .025`) with `80 mg/day` standardized *Zanthoxylum armatum* extract versus placebo, weighed against baseline imbalance and opposite name-to-face memory accuracy.
- **Ground cayenne pepper and Parkinson dystonia severity ([0327](statements/0327.txt), Maybe True, 50.005 — minimal signal):** Newly unlocked 17th symptom (Phase 2 deep audit). Published focal eyelid dystonia (blepharospasm) clinical case (Leon-Sarmiento 2005, `PMID:16258648`) reported rated dystonia severity falling from 4 to 1 at six months following transdermal capsaicin patch treatment alongside an inconclusive 5-volunteer blink-rate check; uncontrolled single-patient design, topical isolated capsaicin, and non-Parkinson blepharospasm keep the lean minimal.
- **Toasted pumpkin seed oil and Parkinson shortened stride ([0428](statements/0428.txt), Maybe False, 50.005 — minimal signal):** Unlocked 14th symptom. Two Parkinson-relevant rodent experiments measured longer stride after oral *Cucurbita pepo* seed extract (`PMID:33759084`) and oral isolated p-coumaric acid (`DOI:10.1177/0976500X221150837`), bridged by roasting chemistry confirming measurable p-coumaric and ferulic acids in roasted pressed pumpkin seed oil (`DOI:10.1002/ejlt.201700110`).
- **Frozen grape and Parkinson muscle rigidity ([0881](statements/0881.txt), Maybe True, 50.005 — minimal signal):** Unlocked 15th symptom. Controlled 6-OHDA MFB-lesioned rat experiment (`PMID:25050252`, `PMC4075680`, `38` Wistar rats) reported lower three-stage muscle stiffness/rigidity scores after 28 days of oral hydroalcoholic red grape seed extract (`100 mg/kg/day`) versus lesioned controls (`p < 0.01`).
- **Grated turmeric and Parkinson olfactory impairment ([0588](statements/0588.txt), Maybe False, 50.005 — minimal signal):** Unlocked 13th symptom. Two independent 12-week randomized placebo-controlled human trials in renal disease favored oral curcumin capsules over placebo: Nasution et al. 2026 (`PMID:42602430`, `n = 48`) and Malekmakan et al. 2023 (`PMID:36967933`, `n = 58`).
- **Ground cinnamon and Parkinson urinary urgency ([0916](statements/0916.txt), Maybe True, 50.005 — minimal signal):** Unlocked 12th symptom. Double-blind randomized overactive-bladder trial (`NCT03532789`, Chen et al. 2020, `n = 66`) favored cinnamon patch over placebo on urgency-frequency (`p < 0.001`) and OABSS (`p < 0.001`), alongside oral mouse cystitis void data (`PMC8716214`).
- **Extra-virgin olive oil and Parkinson constipation ([0072](statements/0072.txt), Maybe True, 50.005 — minimal signal):** Double-blind randomized trial in 140 analyzed adults with functional constipation (Joukar et al. 2025, `PMC12694839`) favored raw extra-virgin over refined olive oil on Rome III severity (`-4.22, p < 0.001`) and week-4 Bristol stool form (`+1.14, p < 0.001`) while excluding neurological disease.
- **Additional minimal-signal leans (58 claims at 50.005, including 8 Phase 2–5 additions):** Covering `pain severity` (`13` total), `fatigue severity` (`12`, incl. Phase 2 [0117](statements/0117.txt) Sichuan pepper, [0348](statements/0348.txt) poached chicken, [0810](statements/0810.txt) raw cantaloupe), `anxiety severity` (`9`), `insomnia severity` (`7`, incl. Phase 5 [0551](statements/0551.txt) dried shiso converging across three independent rodent *Perilla frutescens* leaf sleep studies `DOI:10.20307/nps.2017.23.1.53`, `DOI:10.1016/j.jff.2024.106345`, `PMID:33246117` plus TCM insomnia context), `constipation severity` (`6`, incl. Phase 2 [0210](statements/0210.txt) ground sumac `PMID:40365186`), `depressive symptom severity` (`6`, incl. Phase 5 [0074](statements/0074.txt) cold-pressed pumpkin seed oil converging across `PMID:21545273` human RCT and `DOI:10.21608/ejchem.2024.310875.10173` chronic-stress rats), `bradykinesia severity` (`3`, incl. Phase 2 [0507](statements/0507.txt) ground turmeric across five independent PD rodent experiments and Phase 3 [0503](statements/0503.txt) ground nigella seed across four independent PD/EPS rodent models incl. Malik 2016 `PMID:27752803`), `swallowing difficulty severity` (`2`), `urinary urgency frequency` (`2`), `rest tremor severity` (`2`), `walking slowness` (`2`), and `executive function impairment` (`1`). Full itemized source-family rationales reside in [scorecards.tsv](followup/scorecards.tsv) and [scorecard-sources.tsv](followup/scorecard-sources.tsv).
- **Brewed lemongrass and daytime sleepiness ([0406](statements/0406.txt), Maybe True at 50.005).** The coded comparison recorded 17/50 waking-sleepiness reports after tea and 13/50 after placebo in healthy volunteers. The paired result was inconclusive, and the binary morning item is indirect for Parkinson daytime sleepiness severity. [Direction audit](followup/direction-bias-audit-nov21/README.md)
- **Open findings.** The 929 open scorecards carry the display label Unknown (Researched). The status ledger contains remaining endpoint, preparation and access gaps. The current exact replay leaves 40,372 original claim–source pairs queued. The Japanese physiology original cleared 24. The Italian Neurology figures and 101 other proceedings access gaps remain documented in dated source texts. [Japanese proceedings and cayenne swallowing](../../research/2025-2029/Food-Experiment-Japanese-Physiology-Capsaicin-Nov22.md) Fifty active priority-four source-access pairs in the latest audit link to dated source records. [Clinical and original-access audit](../../research/2025-2029/Food-Experiment-Clinical-Originals-Rosemary-Access-Nov22.md) The indexed shared-original audit gives the exact source-access gaps for 208 of those pairs. [Source-gap digest](../../research/2025-2029/Food-Experiment-Shared-Original-Access-Nov22.md) [Status ledger](followup/research-status.tsv) · [Replay](followup/context-coverage/replay-summary.txt)

The original-access audit recorded gaps for 53 retained pairs and identified two incorrect imported archival locators. The printed-page follow-up resolved two of those access holds and indexed the 12 retained priority-three gaps. [Printed-page follow-up](followup/printed-pages-and-clinical-context-nov22/README.md) [Research gap digest](../../research/2025-2029/Food-Experiment-Round-1-Research-Gaps-Nov22.md) · [Exact gap list](followup/priority-four-sources-and-gaps-nov22/source-gaps.tsv)

The ground-turmeric pain scorecard retains a minimal easing signal after the November 2026 Cochrane synthesis, 39-person spondyloarthritis survey, extract trial and Parkinson nanomicelle pilot were checked. The synthesis effect falls below its clinical-importance threshold and the Parkinson trial gives no separate pain estimate. [Turmeric and original collections audit](followup/five-original-collections-and-turmeric-nov22/README.md)

The dried-date pain scorecard was checked against the whole-fruit crossover and the original distillate migraine registry. The registry outcome fields conflict and the registered Parkinson fiber-bar studies have no posted standalone pain result. Claim 0502 remains Unknown. [June and July original-source checkpoint](followup/june-july-originals-and-date-pain-nov22/README.md)

### Search coverage and limits

- **First-pass baseline:** All 30,593 baseline archive files were read with zero extraction failures ([local-coverage.tsv](local-coverage.tsv)), and 2,000 neutral Europe PMC queries covered all 1,000 frozen statements ([queries.tsv](queries.tsv)).
- **Exact context overlay & deep P1–P5 screening:** The uncapped original Europe PMC overlay spans 61,252 claim–source pairs across 34,099 source keys (`20,391` body or primary context reviews and `226` abstract-depth reviews). The open queue contains 12 priority-three access holds, 1,539 priority-four pairs, 2,894 priority-five pairs and 36,057 priority-six pairs. [Context coverage](followup/context-coverage/README.md) · [Study assessments](followup/assessments.tsv)
- **2026 external lab/clinical & cultural expansion:** Phases 2–4 conducted live PubMed and ClinicalTrials.gov v2 sweeps across all 141 Round 1 ingredients and the 16 symptoms that were open at that checkpoint (archiving 16 new primary lab/clinical studies including `PMID:29576695`, `PMID:30013404`, `PMID:32899274`, `PMID:37484231`, `PMID:41878684`, `PMID:21769642`, `PMID:27430236`, `PMID:27752803`, `PMID:30159851`, `PMID:34802467`, `PMID:38903548`, `PMID:39168304`, `PMID:39294525`, `PMID:41252180`, `PMID:41661604`, `PMID:42638917`) and expanded the cultural/experiential archive by 16 new records (`8` peer-reviewed ethnobotanical/traditional/qualitative/ceremonial records + `8` anonymized public Parkinson's UK forum conversations), bringing the cultural archive to **`128 / 128` verified records** (`research.culture`) and **`128 / 128` (`100%`) mapped graph topics** in `experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv`.
- **Oracle-to-Nyx web UI auto-sync & `Unknown (Researched)` workflow:** `experiments/tools/parkinsons-oracle/build.ps1` automatically rebuilds the Nyx web UI (`app.js`, `oracle.css`, glyphs, gallery, `graph.json` + `.gz`) whenever the Oracle or catalog refreshes (unless `-SkipWeb` is passed). All seven rounds' `AGENTS.md` instructions codify `followup/research-status.tsv` and `foodexperiment.researchstatus verify-complete` so an open claim with a recorded research-status row displays as **`Unknown (Researched)`** in Oracle MCP and the Nyx Web UI.
- **Cross-round transfer readiness (Rounds 2–7):** Native FPC `foodexperiment.roundtransfer` (`8/8` checked tests) verified all six expansion freezes (`5,930` claims, zero cross-round duplicates) and mapped `4,016 / 5,930` (`67.7%`) expansion claims—including `736 / 1,000` (`73.6%`) of Round 2—to existing Round 1 scorecards, assessments, or matrix-distinct siblings. [Transfer readiness](followup/round-transfer-readiness-nov21/README.md)
- **Active clinical trials monitored (live ClinicalTrials.gov v2 check 2026-11-21):** Ginger-PD (`NCT07882108`, `RECRUITING`, `hasResults=false`), NUTRI-GUT-PD (`NCT07213856`, `RECRUITING`, `hasResults=false`), PRIME (`NCT07097103`, `NOT_YET_RECRUITING`, `hasResults=false`), Grape Powder (`NCT07214428`, `ACTIVE_NOT_RECRUITING`, `hasResults=false`), plus `UMIN000055134`.
- **Historical checkpoint archive:** The complete chronological log of checkpoints through P156 is preserved verbatim in [followup/checkpoint-log.md](followup/checkpoint-log.md).

## Directional verdicts

- [0019](statements/0019.txt) **Maybe True** (50.005%) Consuming toasted nigella seed reduces depressive symptom severity in people with Parkinson's disease.
- [0025](statements/0025.txt) **Maybe False** (50.005%) Consuming fresh sage worsens pain severity in people with Parkinson's disease.
- [0039](statements/0039.txt) **Maybe False** (50.005%) Consuming cold-pressed sesame oil worsens anxiety severity in people with Parkinson's disease.
- [0060](statements/0060.txt) **Maybe False** (50.005%) Consuming dried sage worsens insomnia severity in people with Parkinson's disease.
- [0063](statements/0063.txt) **Maybe False** (55%) Consuming ground saffron worsens depressive symptom severity in people with Parkinson's disease.
- [0065](statements/0065.txt) **Maybe True** (50.005%) Consuming cold-pressed walnut oil reduces pain severity in people with Parkinson's disease.
- [0072](statements/0072.txt) **Maybe True** (50.005%) Consuming extra-virgin olive oil reduces constipation severity in people with Parkinson's disease.
- [0074](statements/0074.txt) **Maybe True** (50.005%) Consuming cold-pressed pumpkin seed oil reduces depressive symptom severity in people with Parkinson's disease.
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
- [0406](statements/0406.txt) **Maybe True** (50.005%) Consuming brewed lemongrass worsens daytime sleepiness severity in people with Parkinson's disease.
- [0428](statements/0428.txt) **Maybe False** (50.005%) Consuming toasted pumpkin seed oil worsens shortened stride severity in people with Parkinson's disease.
- [0485](statements/0485.txt) **Maybe False** (55%) Consuming dried saffron worsens fatigue severity in people with Parkinson's disease.
- [0503](statements/0503.txt) **Maybe False** (50.005%) Consuming ground nigella seed worsens bradykinesia severity in people with Parkinson's disease.
- [0507](statements/0507.txt) **Maybe True** (50.005%) Consuming ground turmeric reduces bradykinesia severity in people with Parkinson's disease.
- [0551](statements/0551.txt) **Maybe True** (50.005%) Consuming dried shiso reduces insomnia severity in people with Parkinson's disease.
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
