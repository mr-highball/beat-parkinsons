# Original report access across the ranked source groups

The initial selection used native FPC ranked source groups on the 54,401-pair checkpoint. The surgery report with three exact pairs was excluded by source key before the current 54,398-pair replay. Each of the 60 selected pairs remained queued in the current checkpoint.

The initial primary scan reached 39 exact body contexts. NLM BioC and Europe PMC supplied additional originals for the lumbar-puncture, medication, movement and related clinical reports. The music trial's Falls Efficacy Scale measures perceived confidence during activities. The paper does not supply a measured fall-frequency contrast.

Three remaining records reached original body depth through alternate journal routes. The free Wiley case first published October 20, 2015 described a resting tremor history, back pain and a qualitative hallucination reduction after quetiapine in a case with muscular dystrophy and parkinsonism. The original Aubby BMJ PDF gives leukocyte glutamate dehydrogenase results and clinical diagnostic vignettes, including dystonia and rest tremor. The SAGE PET report includes an incidental acute pain reference, stimulation state and part-level motor scores, and gives no fatigue outcome or separate rigidity result. [Paucar original](https://movementdisorders.onlinelibrary.wiley.com/doi/full/10.1002/mdc3.12247) · [Aubby original](https://jnnp.bmj.com/content/jnnp/51/7/893.full.pdf) · [Jørgensen original](https://journals.sagepub.com/doi/10.1177/0271678X20982389)

## Access attempts on the earlier pass

# Abstract/full-text follow-through

## Recovered originals

The first-stage receipt lists 13 source groups at full-body depth and six at abstract depth. I recovered four additional source bodies through the official NLM PMC OpenAccess BioC endpoint; these are supplied as 12 replacement rows in `body-overrides.tsv` (PMIDs 30738748, 32536782, 32804101, 33603686). PMID 32070122 was also recovered through Europe PMC fullTextXML and its three replacement rows are included. After applying the five-group override, 17/20 source groups are at complete-body depth, two remain at abstract depth, and one remains pending. Every override has `review_basis=full_text` and was generated from an exact source+claim pair in `ranked-exact-pairs.tsv`.

The recovered papers retain contextual, not dietary, relevance. PMID 30738748 reports headache (13%) and low-back pain (6.5%) as lumbar-puncture adverse events, not a PD pain outcome. PMID 32070122 reports a 46-person PD music RCT; Falls Efficacy Scale improved versus control (MD 6.5, 95% CI 3.0–10.0, p=.001), but actual falls were not measured. PMID 32536782 measures center-of-pressure sway/postural behavior, not fall frequency, rigidity, or fatigue. PMID 32804101 tests pimavanserin for PD depression (HAMD-17); it includes broad MDS-UPDRS III safety assessment, while rest tremor is an inclusion symptom and apathy is background discussion, not a target endpoint. PMID 33603686 analyzes social-media posts; pain, falls and apathy appear as coded mentions, without food exposure or clinical severity scales. The orange match in that article is a chart-bar color, not an orange ingredient.

## Remaining routes and barriers

- PMID 3204397 / PMCID PMC1033190: PubMed abstract available. PMC reader gave reCAPTCHA; the NLM BioC endpoint returned HTTP 200 with a 6,140-character response and zero passages; Europe PMC `/fullTextXML` returned HTTP 500; official BMJ PDF route `https://jnnp.bmj.com/content/51/7/893.full.pdf` returned HTTP 403. The source remains abstract-only because its abstract describes a leukocyte enzyme assay, not the mapped symptom outcomes.
- PMID 33461410 / PMCID PMC8327106: PubMed abstract available. PMC reader gave reCAPTCHA; NLM BioC returned HTTP 200 with 6,140 characters and zero passages; Europe PMC `/fullTextXML` returned HTTP 500; SAGE DOI full-text route `https://journals.sagepub.com/doi/full/10.1177/0271678X20982389` returned HTTP 403. Retain abstract depth; the abstract reports broad motor measures but no isolated mapped rigidity outcome.
- PMID 30713914 / PMCID PMC6353534: no PubMed abstract. PMC reader gave reCAPTCHA; NLM BioC returned HTTP 200 with 6,140 characters and zero passages, and Europe PMC fullTextXML returned HTTP 500. Keep its three exact rows pending; title alone is insufficient to assess the symptoms.

Files in `raw/` preserve each downloaded response. The stable public API routes are also used as `local_reference` in the replacement rows.

Public PMC XML-rendering routes also recovered the Aubby and Jørgensen article bodies. These corroborate the matched BMJ and SAGE versions above. [Aubby public XML](https://pmc.ncbi.nlm.nih.gov/articles/PMC1033190/?report=xml) · [Jørgensen public XML](https://pmc.ncbi.nlm.nih.gov/articles/PMC8327106/?report=xml)
