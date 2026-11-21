# Priority-5 Non-Homograph Directional-Symptom PMC JATS XML Screen (November 21, 2026)

## Scope

- Target slice: all `735` remaining non-homograph Priority-5 claim–source pairs (`578` unique source keys, `571` unique PMCIDs, `7` pairs without PMCID) across the directional Parkinson's symptoms after excluding homograph ingredients (`date`, `fig`, `sage`, `orange`) and the `243`-pair Milestone 4 zero-directional-symptom slice ([p5-zerodir-pmcscreen-nov21](../p5-zerodir-pmcscreen-nov21/README.md)).
- Oracle-first lookup: queried `oracle_find_sources` across all `577` Oracle-supported identifiers (`13/577` strict hits at catalog revision `273`; logged via `oraclecoverage.merge.exe` in batch `p5-nonhomograph-rest-nov21`).
- Retrieval & native FPC screening: retrieved `571 / 571` (`100%`) unique PMCIDs via official NCBI PMC E-utilities JATS XML (`71` reused from Milestone 4 cache + `500` newly fetched) and screened all `728` pairs with XML using `foodexperiment.pmcscreen.exe`.

## Screening outcome (`728` pairs with XML)

| Category | Pairs | Handling |
| --- | ---: | --- |
| `zero_body_collision` | 30 | Reconciled as `excluded` (`full_text`) — zero canonical or alias matches in title, abstract, or body |
| `body_match` (verified exclusions) | 147 | Individually verified full-text collisions reconciled as `excluded` (`full_text`): `7` `body_hits=0` title/abstract-only mentions (`Chicken-Egg` idiom, `green coffee beans`, *Asparagus racemosus*), `100%` of `cod` (`Cape Cod`, `COD` drills), `egg` (`EGG` exergame group, `chicken-and-egg`), `cherry` (`Cherry et al.`, `coffee cherry`), `tomato` (grocery prop), `salmon` (`Salmon` authors, `Salmon` RNA-seq software, WGCNA `ME-salmon` module, `salmon sperm DNA`, docking color), `chicken` (IgY antibodies, poultry/veterinary, `chicken pox`), `mango` (`Mango` MRI viewer, `Mango virus`), `Raspberry Pi`, `brine shrimp`, `grape sign` MRI, `garlic clove`, `shell ginger`, `Jonathan Trout`, FMT `coffee filter`, and `54` pure laboratory/placebo oil vehicles (`corn oil`, `sesame oil`, `olive oil`, `sunflower oil`, `peanut oil`, `almond oil`, `flaxseed oil`) |
| `body_match` (verified `related`) | 1 | `0812` / `PMID:39085864` (`PMC11290174`, Soltani et al. 2024) — double-blind nano-curcumin CSFP RCT (`n=42`) favoring SF-36 Bodily Pain (`+13.9 vs -2.4, p<0.001`) and BDI-II depression (`p=0.046`) |
| `body_match` (held for deeper review) | 439 | Remaining substantive review/preclinical/clinical discussions retained in Priority 5 |
| `no_body` | 107 | Non-OA publisher stubs without `<body/>` in NCBI PMC XML — held in queue |
| `collection_hold` | 3 | Multi-abstract / proceedings XML collections — held safely without automated exclusion |
| `pmid_mismatch` | 1 | XML `<article-id pub-id-type="pmid">` differed from queued PMID — held safely |

## Newly cataloged primary human clinical trials (`research/`)

1. **Soltani et al. (2024), *Trials*** (`PMID:39085864`, `PMC11290174`, `IRCT20131125015536N8`): 12-week double-blind placebo-controlled trial (`n=42` analyzed) of 80 mg/day nano-curcumin in coronary slow flow phenomenon; improved SF-36 Bodily Pain (`p < 0.001`), PCS (`p < 0.001`), MCS (`p = 0.02`), and BDI-II depression distribution (`p = 0.046`), while SF-36 Vitality was inconclusive (`p = 0.18`). Cataloged in [`research/2020-2024/Source-Text/2024-PMID39085864-Soltani-NanoCurcumin-CSFP-Pain-Depression.txt`](../../../research/2020-2024/Source-Text/2024-PMID39085864-Soltani-NanoCurcumin-CSFP-Pain-Depression.txt).
2. **Herrlinger et al. (2018), *J Altern Complement Med*** (`PMID:29314866`, `PMC5779242`): 90-day 3-arm double-blind placebo-controlled trial (`N=90`) of 900/600 mg/day aqueous *Mentha spicata* extract in older adults with age-associated memory impairment; improved ease of getting to sleep (`p = 0.0046`), working memory (`p = 0.0469`), and spatial working memory (`p = 0.0456`), with null Power/Continuity of Attention (`p = 0.9312` / `0.8881`), null POMS fatigue-inertia (`p = 0.2111`), and no pain efficacy endpoint (`0728` excluded for pain). Cataloged in [`research/2015-2019/Source-Text/2018-PMID29314866-Herrlinger-Spearmint-Extract-Memory-Sleep-Mood.txt`](../../../research/2015-2019/Source-Text/2018-PMID29314866-Herrlinger-Spearmint-Extract-Memory-Sleep-Mood.txt).

## Replay impact

- Reconciled **`178`** full-text reviews via `foodexperiment.contextintake.exe` (`178 new; 0 upgraded; total exact-reviews = 18,881`).
- Context queue reduced from `41,337` to **`41,159`** (`Priority 5: 3,077 -> 2,899`; `body_or_primary_context_reviewed: 19,560 -> 19,738`; `0` archive identity discrepancies).
