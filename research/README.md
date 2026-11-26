# Parkinson’s research archive

Historical cultural sources are organized by their verified document dates. The indexed periods are [1595–1599](1595-1599/README.md), [1660–1664](1660-1664/README.md), [1675–1679](1675-1679/README.md), [1800–1804](1800-1804/README.md), [1805–1809](1805-1809/README.md), [1815–1819](1815-1819/README.md), [1825–1829](1825-1829/README.md), [1830–1834](1830-1834/README.md).

The initial collection snapshot is **November 11, 2026**. Collection and evidence review continue in the [experiment work record](../experiments/1000_see_what_sticks_food/WORK.md). Each period covers five calendar years; the active [2025–2029 bucket](2025-2029/README.md) is partial.

The November 11 snapshot contains **430 annotated entries** across 33 periods, including 59 food and nutrition entries. The search indexes contain 133,596 Europe PMC literature records, 187 archival PubMed records with one overlap, and 5,075 ClinicalTrials.gov registrations.

James Parkinson published *An Essay on the Shaking Palsy* in 1817. The archive starts in 1865 as requested, when William R. Sanders used the English eponym. Archival research traces French usage by Charcot and Vulpian to 1861. The first bucket documents that earlier context. [1817 essay](https://www.gutenberg.org/ebooks/23777) · [1865 Sanders article](https://pubmed.ncbi.nlm.nih.gov/29646559/) · [Naming history and archival citations](https://www.nature.com/articles/s41582-019-0160-x)

## Browse by period

- [1865-1869](1865-1869/README.md) · [1870-1874](1870-1874/README.md) · [1875-1879](1875-1879/README.md) · [1880-1884](1880-1884/README.md) · [1885-1889](1885-1889/README.md)
- [1890-1894](1890-1894/README.md) · [1895-1899](1895-1899/README.md) · [1900-1904](1900-1904/README.md) · [1905-1909](1905-1909/README.md) · [1910-1914](1910-1914/README.md)
- [1915-1919](1915-1919/README.md) · [1920-1924](1920-1924/README.md) · [1925-1929](1925-1929/README.md) · [1930-1934](1930-1934/README.md) · [1935-1939](1935-1939/README.md)
- [1940-1944](1940-1944/README.md) · [1945-1949](1945-1949/README.md) · [1950-1954](1950-1954/README.md) · [1955-1959](1955-1959/README.md) · [1960-1964](1960-1964/README.md)
- [1965-1969](1965-1969/README.md) · [1970-1974](1970-1974/README.md) · [1975-1979](1975-1979/README.md) · [1980-1984](1980-1984/README.md) · [1985-1989](1985-1989/README.md)
- [1990-1994](1990-1994/README.md) · [1995-1999](1995-1999/README.md) · [2000-2004](2000-2004/README.md) · [2005-2009](2005-2009/README.md) · [2010-2014](2010-2014/README.md)
- [2015-2019](2015-2019/README.md) · [2020-2024](2020-2024/README.md) · [2025-2029](2025-2029/README.md)

## How the collection works

- **Cultural-and-Experiential/** in every period collects traditional practices, ceremonial accounts, local knowledge and public personal reports separately from formal-study archives. Source authenticity and treatment efficacy are separate questions; these accounts carry lower efficacy weight than controlled studies. [Record policy and date handling](Cultural-and-Experiential.md).
- **Source-Text/** contains locally saved UTF-8 source text and catalogs. The annotated notes remain available alongside the source material. [Text coverage by period](Source-Text-Coverage.tsv)
- **Annotated records** summarize selected original sources, including historical scans, clinical studies, pathology and laboratory research, regulatory records, and documented care models. Each period links to the categories with collected material.
- **Observations** contains major and minor findings, a comparison with the immediately preceding period, and specific collection gaps. Comparisons distinguish replication, qualification, conflicting results, changed methods and unanswered questions.
- **Literature-Index.tsv** contains searchable Europe PMC metadata for PubMed records matched by disease terms in the title or abstract or by the Parkinson Disease MeSH heading. The index includes publication types, PMID, DOI and PMCID when available. [Europe PMC search API](https://dev.europepmc.org/RestfulWebService)
- **Archival-PubMed.tsv** supplements pre-1945 searches with PubMed’s publication-date field and historical terminology, including some adjacent encephalitic literature. There can be overlap with the Europe PMC index. Older titles and terms can also match unrelated people or disorders. [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/)
- **Study-Registry.tsv** captures ClinicalTrials.gov records matched by the condition query *Parkinson Disease*, grouped by first posting date. Status and posted-results indicators reflect the retrieval snapshot. A posted result is a registry field, and each study page supplies its design and outcomes. [ClinicalTrials.gov API](https://clinicaltrials.gov/data-api/api)

[Coverage by period](Index-Coverage.tsv) gives the row counts for the Europe PMC and ClinicalTrials.gov indexes. A header-only TSV means that search returned zero records for that period. Archival notes and scans can fill gaps in modern indexes. Use the PMID to open `https://pubmed.ncbi.nlm.nih.gov/{PMID}/` or the NCT ID to open `https://clinicaltrials.gov/study/{NCT_ID}`. Use a text editor or a tab-separated import to search the indexes. For example, this command searches titles and metadata for several nutrition terms.

```powershell
rg -i -g Literature-Index.tsv 'mediterranean|ketogenic|mucuna|protein redistribution' research
```

## Categories

| Category | Material collected |
| --- | --- |
| Clinical and diagnosis | Case descriptions, diagnostic criteria, progression, staging, imaging, biomarkers and differential diagnosis |
| Mechanisms and models | Neuropathology, genetics, neural circuits, cellular models, animal studies and gut–brain research |
| Drugs and remedies | Approved and experimental medicines, historical remedies, repurposing, null trials and adverse effects |
| Procedures and devices | Ablation, deep brain stimulation, infusion systems, grafts, and devices used in intervention or monitoring |
| Food and nutrition | Food patterns, specific foods, supplements, drug–food interactions, tolerability and nutritional outcomes |
| Movement and rehabilitation | Gait, balance, exercise, cueing, physiotherapy, occupational therapy, speech and swallowing |
| Risk and prevention | Incidence, occupational and environmental exposures, possible protective associations and prodromal factors |
| Nonmotor and daily life | Sleep, mood, cognition, pain, autonomic symptoms, swallowing, disability and quality of life |
| Community and care | Caregiving, delivery and access, palliative care, patient experience, advocacy and registries |
| History and context | Original texts, terminology, historical methods, and related disorders where the link is documented |

## Adding records

Use the original public date when it can be established. Note an online-first date, later issue date, translation, reprint, retrospective account or uncertain date when that affects placement. The Europe PMC index uses the service’s first-publication date. Put a study in its main category and cross-link from another category when the distinction matters.

Capture study design, population or model, comparison, duration, endpoint, result direction, important adverse effects or limitations, and a stable source link where available. A food association with future diagnosis, a change in constipation or motor scores, and a treatment’s effect on progression are separate outcomes. Keep null findings and harms beside favorable findings. Describe adjacent conditions, historical terminology and animal models explicitly so the evidence can be read in context.

The indexes are discovery lists and have not been individually screened. They omit material outside their search sources, such as some early books, non-indexed and non-English literature, conference proceedings, registries outside ClinicalTrials.gov, and indirect studies using different terms. The annotated files represent the first reading pass. They include historical interventions and experimental results for research purposes.

## Local source text

The November 11 collection includes **25,049 PMC article texts, 38 historical transcriptions and 5,075 trial registry records**, totaling about 1.7 GB of UTF-8 text. The coverage table shows how much of the larger literature catalog has a local copy. [Text coverage by period](Source-Text-Coverage.tsv)

- `Source-Text/Annotated-Sources.tsv` lists the source links in that period’s notes and observations. It identifies the annotation and links it to local text where the source could be matched.
- `Source-Text/Literature-Catalog.tsv` maps each indexed literature citation to its local text status. The `citation_index` column points to the bibliographic details in the original index. The `text_path` column is relative to the period’s `Source-Text` folder.
- `Source-Text/Registered-Studies.tsv` maps trial registrations to `Trials/NCT<number>.txt`. The files preserve public registry descriptions, eligibility, interventions and outcome definitions, plus aggregate results where posted. They identify the API snapshot and which material was formatted or omitted. [ClinicalTrials.gov data terms](https://clinicaltrials.gov/about-site/terms-conditions)
- `PMC<number>.txt` files contain the U.S. National Library of Medicine’s plain-text export with a provenance header. The collector checks the article version, CC0, CC BY, or CC BY-SA license, and file checksum using the PMC Cloud Service. PMC’s export may flatten tables or omit figures, layout, and supplemental files. The header records the license, version and source. [NLM PMC Cloud Service](https://pmc.ncbi.nlm.nih.gov/tools/pmcaws/) · [Dataset terms and format](https://pmc-oa-opendata.s3.amazonaws.com/README.txt)
- Earlier books, chapters, and journal articles use historical transcriptions or OCR. Their headers identify the edition, source, and scope of the saved text. OCR may need checking against the scan.

`text_available` means a local text file was verified. The accompanying coverage field distinguishes article text, complete works, and excerpts. `no_eligible_version` means the PMC lookup did not find a version with a license and text file within this collection’s scope. `download_error` records a failed retrieval. `text_pending` means that the catalog has a citation or source link and no matched local text from this pass. It includes papers outside the PMC search and texts whose reuse rights are unknown. This is a dated snapshot. Consult the source for the latest version and corrections.

To search the text itself across every period, run this from the repository root.

```powershell
rg -il -g '*.txt' 'protein redistribution|mucuna pruriens' research
```

## Refresh the indexes

Run the collector from the repository root with Python 3.8 or later. It queries public APIs and updates the generated TSVs. The supplied cutoff limits publication or first posting dates. Later runs can capture indexing and registry changes.

```powershell
python research/collect_indexes.py --through 2026-11-11
```

Use `--output` for a separate snapshot or `--archival-only` to refresh only the early PubMed supplement. The script checks pagination counts before publishing each index.

Refresh source text from the existing indexes, then rebuild the catalogs.

```powershell
python -B research/collect_source_text.py --scope all
python -B research/collect_trial_text.py
python -B research/build_source_catalog.py
```

`--scope annotated` collects only PMC sources matched to annotated entries. Repeated runs reuse previously saved files and lookup outcomes. To recheck unavailable versions after a later rights or availability change, refresh the retrieval manifest by removing the relevant rows before rerunning the collector.
