# Parkinson's food thought experiment results

Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.

- Frozen SHA-256 `6ec7f4720714723e201f7dcf2c03001d65aed7f2409b4f15822905b6d05dbdee`
- [Statement verdict ledger](verdicts.tsv)
- [First-pass search ledger](queries.tsv) with 2000 completed records and 1000 statements covered
- [Counts by category and claim direction](results-summary.tsv)
- [Per-citation source-depth and verification milestone ledger](followup/source-depth.tsv) (`382` `original_body_verified` / `425` `first_pass_screened` across `807` unique cited files)

## Verdict counts

| Verdict | Local review | Current verdict |
| --- | ---: | ---: |
| Unknown | 1000 | 947 |
| Maybe True | 0 | 31 |
| Maybe False | 0 | 22 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

All 1,000 frozen Round 4 claims (`0001`–`1000`) have been researched using the Oracle-first workflow, Rounds 1–3 evidence transfer, 2,000 neutral Europe PMC queries ([queries.tsv](queries.tsv)), live PubMed XML, Europe PMC / NCBI PMC open-access full-text XML, ClinicalTrials.gov v2 sweeps, targeted adversarial opposing-evidence checks across all proposed directional claims, and inclusive cultural/traditional/public forum collection. Every claim carries a validated v1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv)), per-citation source-depth milestone audit ([source-depth.tsv](followup/source-depth.tsv)), and completion audit row ([research-status.tsv](followup/research-status.tsv)).

Round 4 spans 35 unique ingredients (13 new pantry-expansion ingredients across all 33 symptoms each—`endive`, `fava beans`, `fenugreek leaf`, `fenugreek seed`, `flaxseed`, `guava`, `hazelnut`, `hemp hearts`, `hempseed oil`, `herring`, `hibiscus`, `honeydew melon`, and `horseradish`—plus 22 shared Rounds 1–3 exposures covering their non-overlapping reserved symptoms). Raw cross-round percentages are not directly comparable across rounds without category and ingredient standardization: Round 4 contains `698` food, `122` spice, `92` oil, and `88` herb claims.

| Verdict / Tier | Count | Notes |
| --- | ---: | --- |
| `Maybe True` | 31 | Directional evidence aligns with frozen hypothesis direction (`6` `limited_clinical_link`, `25` `minimal_signal`) |
| `Maybe False` | 22 | Directional evidence opposes frozen hypothesis direction (`3` `limited_clinical_link`, `19` `minimal_signal`) |
| `Unknown` (`Unknown (Researched)`) | 947 | Exhaustively checked; no defensible net directional lean (`open`, anchor `50`) |
| **Total frozen claims** | **1,000** | `500` frozen `reduces` / `500` frozen `worsens` |

By v1 scorecard tier and direction:
- **`limited_clinical_link` (anchor `51`):** `9` claims (`4` easing leans, `5` worsening leans)
- **`minimal_signal` (anchor `50.005`):** `44` claims (`40` easing leans, `4` worsening leans)
- **`open` (anchor `50`, displayed as `Unknown (Researched)`):** `947` claims
- **Symptom breadth:** `53` directional claims across `18` distinct symptoms and `20` ingredients (`15` ingredients remained `100%` `Unknown (Researched)`: `dill seed`, `endive`, `fenugreek leaf`, `flaxseed oil`, `grapeseed oil`, `green beans`, `green cabbage`, `green peas`, `guava`, `hazelnut`, `hazelnut oil`, `hibiscus`, `honeydew melon`, `horseradish`, `kidney beans`).
- **Category breakdown:** `food` (`20` Maybe True, `19` Maybe False, `659` Unknown / `698` total), `spice` (`10` Maybe True, `2` Maybe False, `110` Unknown / `122` total), `herb` (`1` Maybe True, `0` Maybe False, `87` Unknown / `88` total), `oil` (`0` Maybe True, `1` Maybe False, `91` Unknown / `92` total).

### Source-depth and verification milestones

Following peer-review best practice, Round 4 separates **first-pass screening** from **original-body verification** in [followup/source-depth.tsv](followup/source-depth.tsv) across all `807` unique cited archive files (`4,104` unique claim–file citations):

| Verification Milestone | Unique Cited Files | Claim–File Citations | Directional-Claim Files | Composition |
| --- | ---: | ---: | ---: | --- |
| `original_body_verified` | `382` (`47.3%`) | `2,425` (`59.1%`) | `117 / 243` | `222` `oa_fulltext_verified` (Europe PMC + NCBI PMC JATS full-text XML), `103` `cultural_or_forum_record` (full public/traditional records), `57` full local `archived_source_text` originals (`>6 KB`) |
| `first_pass_screened` | `425` (`52.7%`) | `1,679` (`40.9%`) | `126 / 243` | `322` `primary_abstract_only` (paywalled / non-OA XML queued for original-body table verification), `94` compact local archive extracts, `9` `registry_protocol_only` (ClinicalTrials.gov v2 without posted results) |
| **Total cited in Round 4** | **`807`** | **`4,104`** | **`243`** | Every directional claim also passed a targeted PubMed `pub_date` + `relevance` adversarial opposing-evidence audit (`210` uncited clinical candidates triaged; `0` unaddressed conflicting human RCTs) |

### Highlighted checked v1 findings

- **Fava beans (*Vicia faba*) — natural dietary L-DOPA with bidirectional clinical-tier motor effects (`0155`–`0187`, `9` directional claims):** Direct Parkinson clinical ingestion studies (`Kempster 1993` `PMID:24352104`, `Rabey 1992` `PMID:1527547`, `Apaydin 2000` `PMID:10760153`, `Vered 1997`) show boiled/cooked *Vicia faba* delivers pharmacologically active levodopa that shortens daily OFF time ([0160](statements/0160.txt), **Maybe True**, `51`, `limited_clinical_link`, eases) while precipitating peak-dose dyskinesia ([0165](statements/0165.txt), **Maybe False**, `51`, `limited_clinical_link`, worsens), alongside `minimal_signal` (`50.005`) easing leans on bradykinesia ([0158](statements/0158.txt)), hand dexterity ([0171](statements/0171.txt)), rigidity ([0174](statements/0174.txt)), rest tremor ([0180](statements/0180.txt)), and walking slowness ([0187](statements/0187.txt)), and `minimal_signal` **worsening** leans on anxiety ([0155](statements/0155.txt)) and dystonia ([0166](statements/0166.txt)). Unstandardized pod/bean L-DOPA variability, lack of decarboxylase inhibitor co-dosing, and G6PD favism contraindication (`Luzzatto & Arese 2018` `PMID:29298156`) are prominently documented.
- **Brewed green tea (*Camellia sinensis*) — four clinical-tier caffeine-bridged PD links (`51`) plus three minimal-signal easing leans (`0589`–`0607`):** Direct Parkinson caffeine trials (`Postuma 2012` `PMID:22855863`, `Postuma 2017` Café-PD `PMID:28954882`, `Shoulson & Chase 1975`) bridged via brewed green tea caffeine kinetics support `limited_clinical_link` (`51`) easing leans on bradykinesia ([0590](statements/0590.txt), Maybe False), daytime sleepiness ([0593](statements/0593.txt), Maybe True), and muscle rigidity ([0605](statements/0605.txt), Maybe True), balanced against a `limited_clinical_link` (`51`) **worsening** lean on dyskinesia ([0597](statements/0597.txt), Maybe True). Three `minimal_signal` (`50.005`) easing leans cover acute attention ([0589](statements/0589.txt), `Dietz 2017` + `Payne 2025` + `Gerolymos 2026` `PMID:42410082`, tempered by chronic 12-month null `Uchida 2024`), acute postprandial/orthostatic pressor protection ([0606](statements/0606.txt), `Son 2012` + `Rakic 1996`, balanced explicitly against modest chronic resting-BP lowering meta-analyses `Li 2015` / `Yildirim-Ayaz 2023` / `PMID:40497293`), and pain ([0607](statements/0607.txt), `Liu 2021` + `Essmat 2021`, tempered by mixed `Hashempur 2018`).
- **Animal-protein daytime LNAA levodopa competition — three clinical-tier (`51`) worsening leans on daily OFF time:** Consistent with Rounds 2–3 calibration (`beef`, `chicken`, `clams`, `cod`, `cow's milk`), boiled egg ([0067](statements/0067.txt), Maybe True), cooked herring ([0773](statements/0773.txt), Maybe False), and plain kefir ([0932](statements/0932.txt), Maybe True) carry `limited_clinical_link` (`51`) worsening leans on daily OFF time via direct PD protein-redistribution trials (`Barichella 2006`, `Tsui 1989`, `Carter 1989`, `Eriksson 1988`) and human postprandial LNAA kinetics (`van Vliet 2017`, `Uhe 1992`, `Milan 2024`). Conversely, plant legumes (`green beans`, `green peas`, `kidney beans`) remained `open` per lower ileal digestibility and blunted EAA surges (`Kashyap 2019/2024`), while `edamame` (`0036` daily OFF time, `0041` dyskinesia — `minimal_signal` easing) reflects soy-protein levodopa-sparing / isoflavone-dyskinesia evidence (`Park 2021`, `Kaplan 2019`, `Bishnoi 2007`).
- **Raw grapefruit (*Citrus × paradisi*) — two medication-interaction worsening leans (`50.005`):** Direct human CYP3A4 intestinal-inhibition pharmacokinetic trials (`Lilja 1998/2000`, `Bailey 1991/2013`, `Hukkinen 1995`, `Garg 1998`) support `minimal_signal` **worsening** leans on daytime sleepiness ([0451](statements/0451.txt), Maybe False, via sedating co-medications such as quetiapine/benzodiazepines) and orthostatic lightheadedness ([0466](statements/0466.txt), Maybe False, via dihydropyridine calcium-channel blockers/antihypertensives).
- **Other pantry-expansion ingredients (`11` additional new ingredients, `14` directional claims):**
  - `fenugreek seed` (`8` minimal-signal easing leans across `0244`–`0276`, anchored by PD adjunct pilot `Nathan 2014` `PMID:24089329` alongside non-PD mood/sleep/pain RCTs, strictly separated from `fenugreek leaf` which stayed `0 / 33` open).
  - `flaxseed` (`4` minimal-signal easing leans: `0311` constipation across 4 ground-flaxseed RCTs `Sun 2020`, `Soltanian 2018/2019`, `Ma 2022`, `Cunnane 1995`; `0321` fatigue; `0324` insomnia; `0329` pain across `Ghaseminasab-Parizi 2022`, `Jafarpour 2026`, `Mirghafourvand 2016`, `Vaziri 2014`, strictly excluding compromised `Khalajinia 2024`).
  - `hemp hearts` (`1` minimal-signal easing lean: `0706` constipation, separated from multi-herb *MaZiRenWan* and CBD/THC cannabinoids).
  - `hempseed oil` (`1` minimal-signal easing lean: `0757` pain, strictly separating cold-pressed dietary seed oil from CBD/THC cannabis oil).
  - `7` new pantry-expansion ingredients stayed `0 / 33` directional (`100%` `Unknown (Researched)`): `endive`, `fenugreek leaf`, `guava`, `hazelnut`, `hibiscus`, `honeydew melon`, and `horseradish`.
- **Additional minimal-signal easing leans across shared Rounds 1–3 exposures (`20` claims at `50.005`):** `grape` (`3`: `0417` attention, `0421` depression, `0426` executive function, tempered by `Bell 2022` GSPE null & `Helmer 2020` unadjusted nulls), `fennel seed` (`2`: `0191` constipation, `0204` pain), `garlic` (`2`: `0373` fatigue, `0381` pain, noting 84% allicin loss on cooking per `Lawson 2018` `PMC6073756` and null OA trial `Salimzadeh 2018`), `ginger` (`2`: `0392` attention, `0402` fatigue anchored by `Crichton 2024` `PMID:37699474` `p=0.002` + `Ashraf 2022` + `Lage 2026` balanced against healthy/endurance nulls), `kiwi fruit` (`2`: `0991` constipation across 7 whole-fruit trials led by `Gearry 2023` & `Chey 2021` vs failed extracts `Kindleysides 2015`/`Holtmann 2025`; `0994` depression anchored by `Billows 2025` GoKiPH `PMC12030757`), `edamame` (`2`: `0036`, `0041`), `kefir` (`1` easing `0931` constipation + `1` clinical worsening `0932` OFF time), `dill weed` (`1`: `0011` constipation), `eggplant` (`1`: `0098` depression, noting `Nielsen 2013` excluded eggplant from Solanaceae FFQ), `fig` (`1`: `0281` constipation across `Baek 2016`, `Pourmasoumi 2019`, `Valizadeh 2025`), and `kale` (`1`: `0903` constipation, `Nishimura 2019` `PMC6893753`).

### Key exclusions, integrity catches, and open findings

- **Full-text integrity, retraction, and methodological catches:** OA full-text inspection and adversarial review identified and excluded multiple compromised or confounded studies from supporting directional verdicts: `Singh RB 1992/1993` guava trials (flagged under the 2005 *BMJ*/*Lancet* data-fabrication investigation), `Chatupos 2024` kale pain (Table 1 listed zero anthocyanins contradicting abstract's 500 mg claim), `Jalal 2020` green-bean pod water (Table 4 contained impossible p-values `14.5385` and `2.889`), `Nguyen 2026` guava jelly (Table 1 revealed mint-syrup arm swap), `Mansoor 2025` guava gel (topical antiseptic with inconsistent Day-7 values), `Amirsalari 2021` garlic endometriosis (severe baseline stage imbalance `p=0.001` and contradictory ANCOVA `p=0.161`), `Khalajinia 2024` flaxseed formulation, retracted `Qi & Ying 2015` (`PMID:28932324`), `Negi 2026` fennel, and `Tasnim 2015` garlic cognition (regression to the mean).
- **Strict botanical, plant-part, matrix, and homonym boundaries:** Separated `fenugreek leaf` (`0 / 33` open) from `fenugreek seed` (`8` directional); separated *Cichorium endivia* (`endive`) from chicory/Belgian endive root (*C. intybus*, `Baert 2021`); separated culinary *Armoracia rusticana* (`horseradish`) from horseradish peroxidase (`HRP`) assay homonyms, *Moringa oleifera* ("horseradish tree"), and 2-herb `Angocin` (*Tropaeolum majus* + *A. rusticana*); separated *Cucumis melo* var. *inodorus* (`honeydew melon`) from cantaloupe-derived `Extramel` SOD supplements; separated whole `grape` from isolated grape seed proanthocyanidin extract (`GSPE`) and `grapeseed oil` (`0` directional); separated culinary `hemp hearts` and `hempseed oil` from CBD/THC cannabis pharmaceuticals; separated `flaxseed oil` (`0` directional in Round 4's symptom set) from whole ground `flaxseed`; and kept `hibiscus` (`0 / 33` open) properly `open` because resting antihypertensive / diuretic RCTs (`outcome_fit = remote`) do not establish orthostatic lightheadedness or urinary urgency worsening while transparently archiving PD hypotension/diuresis cautions.
- **Open findings (`947` claims):** All `947` open claims carry `verdict = Unknown` and `research_status = researched` (displaying as `Unknown (Researched)` in Parkinson's Oracle MCP and the Nyx web UI), with explicit unresolved exposure, preparation, endpoint, and Parkinson-population gaps recorded per claim in [research-status.tsv](followup/research-status.tsv).

### Search coverage and limits

- **Oracle-first & transfer baseline:** Audited all 35 Round 4 ingredients against catalog revision `283` (`40,804` indexed files, `0` read errors) and transferred applicable Rounds 1–3 evidence across the 22 shared exposures before external retrieval. First-pass coverage rates (`0 / 35` strict claim hits with `35 / 35` partial leads; `2 / 513` strict baseline source hits across `513` newly verified primary PMID/NCT IDs) are logged in [experiments/oracle-coverage/](../oracle-coverage/README.md).
- **External clinical & scientific retrieval:** Completed `2,000 / 2,000` neutral Europe PMC queries ([queries.tsv](queries.tsv), `0` failed queries, `1,112` with hits, `2,790` unique PMIDs), full live PubMed XML, Europe PMC / NCBI PMC OA full-text XML, and ClinicalTrials.gov v2 sweeps across all 35 ingredients, plus targeted PubMed `pub_date` + `relevance` adversarial opposing-evidence audits across all `53` directional claims (`210` uncited clinical candidates triaged), archiving `514` newly extracted primary source texts under chronological `research/YYYY-YYYY/Source-Text/` buckets.
- **Inclusive cultural & experiential collection:** Archived `80` new traditional-practice, local-knowledge, personal-report, and anonymized public forum conversation records (Parkinson's UK Discourse, Cure Parkinson's HealthUnlocked, peer-reviewed ethnobotanical texts) under `research/YYYY-YYYY/Cultural-and-Experiential/`, bringing total verified cultural records to `375` with full topic mapping in `experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv`.
- **Ledger depth:** `1,000` v1 scorecards, `4,007` scorecard source-family rows, `3,715` per-claim study assessments, `807` per-citation source-depth rows (`382` `original_body_verified`, `425` `first_pass_screened`), `0` scorecard mismatches against live `oracle_check_scorecard`, and `1,000 / 1,000` passing `foodexperiment.researchstatus verify-complete`.

## Directional verdicts

- [0011](statements/0011.txt) **Maybe True** (50.005%) Consuming fresh dill weed reduces constipation severity in people with Parkinson's disease.
- [0036](statements/0036.txt) **Maybe True** (50.005%) Consuming cooked edamame reduces daily off time in people with Parkinson's disease.
- [0041](statements/0041.txt) **Maybe True** (50.005%) Consuming steamed edamame reduces dyskinesia severity in people with Parkinson's disease.
- [0067](statements/0067.txt) **Maybe True** (51%) Consuming boiled egg worsens daily off time in people with Parkinson's disease.
- [0098](statements/0098.txt) **Maybe True** (50.005%) Consuming roasted eggplant reduces depressive symptom severity in people with Parkinson's disease.
- [0155](statements/0155.txt) **Maybe True** (50.005%) Consuming cooked fava beans worsens anxiety severity in people with Parkinson's disease.
- [0158](statements/0158.txt) **Maybe False** (50.005%) Consuming boiled fava beans worsens bradykinesia severity in people with Parkinson's disease.
- [0160](statements/0160.txt) **Maybe True** (51%) Consuming boiled fava beans reduces daily off time in people with Parkinson's disease.
- [0165](statements/0165.txt) **Maybe False** (51%) Consuming cooked fava beans reduces dyskinesia severity in people with Parkinson's disease.
- [0166](statements/0166.txt) **Maybe False** (50.005%) Consuming cooked fava beans reduces dystonia severity in people with Parkinson's disease.
- [0171](statements/0171.txt) **Maybe True** (50.005%) Consuming boiled fava beans reduces hand dexterity impairment in people with Parkinson's disease.
- [0174](statements/0174.txt) **Maybe False** (50.005%) Consuming boiled fava beans worsens muscle rigidity severity in people with Parkinson's disease.
- [0180](statements/0180.txt) **Maybe False** (50.005%) Consuming boiled fava beans worsens rest tremor severity in people with Parkinson's disease.
- [0187](statements/0187.txt) **Maybe True** (50.005%) Consuming boiled fava beans reduces walking slowness in people with Parkinson's disease.
- [0191](statements/0191.txt) **Maybe False** (50.005%) Consuming ground fennel seed worsens constipation severity in people with Parkinson's disease.
- [0204](statements/0204.txt) **Maybe True** (50.005%) Consuming ground fennel seed reduces pain severity in people with Parkinson's disease.
- [0244](statements/0244.txt) **Maybe True** (50.005%) Consuming ground fenugreek seed reduces anxiety severity in people with Parkinson's disease.
- [0247](statements/0247.txt) **Maybe True** (50.005%) Consuming toasted fenugreek seed reduces bradykinesia severity in people with Parkinson's disease.
- [0251](statements/0251.txt) **Maybe True** (50.005%) Consuming toasted fenugreek seed reduces depressive symptom severity in people with Parkinson's disease.
- [0261](statements/0261.txt) **Maybe False** (50.005%) Consuming ground fenugreek seed worsens insomnia severity in people with Parkinson's disease.
- [0263](statements/0263.txt) **Maybe True** (50.005%) Consuming toasted fenugreek seed reduces muscle rigidity severity in people with Parkinson's disease.
- [0266](statements/0266.txt) **Maybe True** (50.005%) Consuming ground fenugreek seed reduces pain severity in people with Parkinson's disease.
- [0269](statements/0269.txt) **Maybe True** (50.005%) Consuming ground fenugreek seed reduces rest tremor severity in people with Parkinson's disease.
- [0276](statements/0276.txt) **Maybe True** (50.005%) Consuming toasted fenugreek seed reduces walking slowness in people with Parkinson's disease.
- [0281](statements/0281.txt) **Maybe True** (50.005%) Consuming raw fig reduces constipation severity in people with Parkinson's disease.
- [0311](statements/0311.txt) **Maybe False** (50.005%) Consuming ground flaxseed worsens constipation severity in people with Parkinson's disease.
- [0321](statements/0321.txt) **Maybe True** (50.005%) Consuming ground flaxseed reduces fatigue severity in people with Parkinson's disease.
- [0324](statements/0324.txt) **Maybe True** (50.005%) Consuming ground flaxseed reduces insomnia severity in people with Parkinson's disease.
- [0329](statements/0329.txt) **Maybe True** (50.005%) Consuming ground flaxseed reduces pain severity in people with Parkinson's disease.
- [0373](statements/0373.txt) **Maybe False** (50.005%) Consuming roasted garlic worsens fatigue severity in people with Parkinson's disease.
- [0381](statements/0381.txt) **Maybe False** (50.005%) Consuming cooked garlic worsens pain severity in people with Parkinson's disease.
- [0392](statements/0392.txt) **Maybe True** (50.005%) Consuming ground ginger reduces attention impairment in people with Parkinson's disease.
- [0402](statements/0402.txt) **Maybe True** (50.005%) Consuming pickled ginger reduces fatigue severity in people with Parkinson's disease.
- [0417](statements/0417.txt) **Maybe False** (50.005%) Consuming frozen grape worsens attention impairment in people with Parkinson's disease.
- [0421](statements/0421.txt) **Maybe True** (50.005%) Consuming frozen grape reduces depressive symptom severity in people with Parkinson's disease.
- [0426](statements/0426.txt) **Maybe True** (50.005%) Consuming frozen grape reduces executive function impairment in people with Parkinson's disease.
- [0451](statements/0451.txt) **Maybe False** (50.005%) Consuming raw grapefruit reduces daytime sleepiness severity in people with Parkinson's disease.
- [0466](statements/0466.txt) **Maybe False** (50.005%) Consuming raw grapefruit reduces orthostatic lightheadedness severity in people with Parkinson's disease.
- [0589](statements/0589.txt) **Maybe False** (50.005%) Consuming brewed green tea worsens attention impairment in people with Parkinson's disease.
- [0590](statements/0590.txt) **Maybe False** (51%) Consuming brewed green tea worsens bradykinesia severity in people with Parkinson's disease.
- [0593](statements/0593.txt) **Maybe True** (51%) Consuming brewed green tea reduces daytime sleepiness severity in people with Parkinson's disease.
- [0597](statements/0597.txt) **Maybe True** (51%) Consuming brewed green tea worsens dyskinesia severity in people with Parkinson's disease.
- [0605](statements/0605.txt) **Maybe True** (51%) Consuming brewed green tea reduces muscle rigidity severity in people with Parkinson's disease.
- [0606](statements/0606.txt) **Maybe False** (50.005%) Consuming brewed green tea worsens orthostatic lightheadedness severity in people with Parkinson's disease.
- [0607](statements/0607.txt) **Maybe True** (50.005%) Consuming brewed green tea reduces pain severity in people with Parkinson's disease.
- [0706](statements/0706.txt) **Maybe False** (50.005%) Consuming hulled hemp hearts worsens constipation severity in people with Parkinson's disease.
- [0757](statements/0757.txt) **Maybe False** (50.005%) Consuming cold-pressed hempseed oil worsens pain severity in people with Parkinson's disease.
- [0773](statements/0773.txt) **Maybe False** (51%) Consuming cooked herring reduces daily off time in people with Parkinson's disease.
- [0903](statements/0903.txt) **Maybe False** (50.005%) Consuming roasted kale worsens constipation severity in people with Parkinson's disease.
- [0931](statements/0931.txt) **Maybe False** (50.005%) Consuming plain kefir worsens constipation severity in people with Parkinson's disease.
- [0932](statements/0932.txt) **Maybe True** (51%) Consuming plain kefir worsens daily off time in people with Parkinson's disease.
- [0991](statements/0991.txt) **Maybe False** (50.005%) Consuming raw kiwi fruit worsens constipation severity in people with Parkinson's disease.
- [0994](statements/0994.txt) **Maybe True** (50.005%) Consuming raw kiwi fruit reduces depressive symptom severity in people with Parkinson's disease.
