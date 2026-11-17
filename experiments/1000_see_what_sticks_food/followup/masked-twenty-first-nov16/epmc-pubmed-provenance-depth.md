# Blimbo P21 bibliographic result screen — 2026-11-16

## Inputs, joins, and depth

Reviewed every appearance in `../epmc/ingredient_results.tsv` against the P21 mapped claim and source identity, and joined the distinct-PubMed set in `../pubmed/pubmed_ids.tsv` on mapped claim plus PMID. The EPMC export contains 11 appearances across five claim-query families: 0643 (three), 0648 (four), 0830 (one), 0645 (one), and 0767 (two). These are preserved one-for-one, in query rank order, in `europe-pmc-screen.tsv`. The screen has 11 rows: 9 related/context leads and 2 unrelated lexical exclusions. The two patents were first pending on “Szechuan lovage” species ambiguity; original Chinese text and botanical references resolved them to Chuanxiong rhizome, so both now remain as related context rather than unresolved matches. EPMC’s AGR:IND609291272 and PMID:40617359 rows are one eugenol article and are counted as one study; both source appearances remain screened for exact tuple coverage.

The two PubMed-only kale records, PMID 39892645 and PMID 36130610, have `europe_pmc_pmid_overlap=No` in the PubMed ID ledger and are separately screened in `pubmed-novel-screen.tsv`. They are linked members of one maternal/fetal flavor-response study family, not independent intervention replications. Pinky’s `../pinky/README.md` and `../pinky/exact/README.md` were used as the source trail; I did not repeat the primary search or independently reconstruct the family linkage.

The EPMC records include indexed abstracts in the frozen P21 result export. For plainly nonmatching contexts, review was limited to those exported abstracts. The two kale records were assessed using Pinky’s exact-source README trail and the indexed-publication identity; Pinky’s materials document article methods/results, cohort overlap, and preparation/outcome mismatch. No additional broad searches were performed. Patent-specific follow-through is recorded in `patent-chuanxiong-identity.md`. Review basis and rationale are recorded per appearance, with the exact query/rank/source_key tuple retained.

## Claim-level findings

- **0643 lovage leaf / pain:** Two patents and one Qishe Pill protocol name Chuanxiong rhizome, not *Levisticum officinale* leaf. The patents claim unrelated dysmenorrhea or chest-pain uses and report animal, not Parkinson or identified human, outcomes. PMID 24099350 is a compound-formula protocol for cervical radiculopathy neck pain, not study results.
- **0648 clove / executive function:** PMID 40908892 is the strongest human contextual lead: an olfactory-training RCT in type 2 diabetes with MCI reports cognitive and executive-domain improvement while clove is one of six odorants. It cannot isolate clove effects and uses odor exposure, not ground clove intake. PMID 40617359/AGR:IND609291272 is one animal eugenol/paraquat study. PMID 19470369 uses clove odor only as a control carrier; it is not a clove treatment.
- **0830 blueberry / voice:** PMID 34996974 is a physics observation of fruit motion on a hotplate; “sound pressure level” refers to popcorn, not voice.
- **0645 spearmint / olfactory impairment:** PMID 31106883 is a forest musk deer olfactory-genome paper with predicted spearmint odor recognition, not an intervention or clinical impairment outcome.
- **0767 soybean oil / daytime sleepiness:** PMID 28964775 uses soybean oil as a rat dietary comparator in an amphetamine/physical-activity study. PMID 15114202 compares intravenous propofol emulsions with soybean-oil excipient and assesses procedural sedation. Neither measures the mapped daytime sleepiness outcome.
- **0793 kale / olfactory impairment:** PMID 36130610 concerns fetal responses after prenatal maternal kale/carrot powder capsules; PMID 39892645 follows neonatal odor responses in that same study family. Powder/capsule exposure and hedonic facial responses do not assess roasted-kale effects on olfactory impairment.

These are contextual and lexical-screen dispositions only. None establishes an exact frozen preparation-and-endpoint effect in Parkinson disease. A missing endpoint or an unmatched abstract is not a null-effect finding.

## Resumption

Start from the exact tuple ledgers and Pinky’s linked cohort note. The 0643 patent identity investigation and boundary note in `patent-chuanxiong-identity.md` resolve both records as Chuanxiong rhizome of *Ligusticum*, not *Levisticum* leaf. No other item in this 11-appearance batch requires full-text retrieval to explain why the indexed result does not directly fit the frozen claim.
