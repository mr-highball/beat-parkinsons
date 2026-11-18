# Cultural, traditional and experiential records

Collect reported practices and experiences as part of the research canon. Preserve what people claim, how the practice is understood in its cultural setting, adverse or contradictory accounts, and what the inspected source can actually establish. A record of a practice is different from evidence that it changes a symptom.

Keep a reported benefit active as a working hypothesis to investigate. Longstanding use, preparation traditions and community experience can identify questions that narrow experiments have not tested. Missing modern studies do not disprove the claim. Investigate support, contradiction, context and harms while retaining the established distinction between a premise and a verified outcome.

Each five-year period has a separate `Cultural-and-Experiential/` folder. Use subfolders when records are added:

- `Traditional-Practices/` for practitioner texts, ethnobotany and inherited remedies.
- `Ceremonial-Accounts/` for ritual, religious or ceremonial contexts.
- `Personal-Reports/` for public first-person experiences and patient-reported claims.
- `Conversations/` for public Reddit and other forum threads or comparable community discussions.
- `Local-Knowledge/` for other community accounts and explanatory beliefs.

Use UTF-8 text for individual source records. Link each addition from the period index and its Observations record. Include an identifiable source URL or bibliographic locator and the specific page, passage or post inspected. Preserve original terminology and translate cautiously; record uncertain species, plant parts, preparations, diagnoses and symptom types. A historical word for shaking or a spiritual interpretation does not by itself establish a modern Parkinson diagnosis or measured rest tremor.

Record these fields explicitly for the categories other than Conversations:

| Field | Requirement |
| --- | --- |
| Title and source | Identify the original account and exact inspected location. |
| Source kind | Traditional text, ethnographic observation, ceremonial account, personal report, or structured patient survey. |
| Publication date and date basis | Separate the document date, event date, claimed historical age and retrieval date. |
| Community/context | Attribute a practice to the source's stated setting; avoid generalizing it to an entire culture. |
| Exposure and reported symptom | Retain preparation, route, other interventions, diagnosis verification and tremor phenotype when known. |
| Reported direction | Benefit, worsening, no perceived effect, mixed, or unspecified; this is the account's claim, not a verdict. |
| Evidence and limits | State whether a comparison, measurement, denominator, adverse outcome or causal attribution exists. |
| Authenticity and efficacy | Evaluate source authenticity separately from evidence for symptom effects. |
| Related research | Link existing clinical/laboratory accessions and conflicting accounts; identify duplicate reports. |
| Access and follow-up | Record unread originals, translations, historical attribution and other unresolved trails. |

### Conversation records

Start with a title, `Collection: Cultural and experiential`, the original public thread URL in `Source`, and a `Date basis`. File the text under the period of the opening post. A year is enough when finer precision is unclear. If the publication year cannot be established, omit it or mark it unknown and supply a `Capture date` with an explicit first-documented-capture basis. A later reply can be dated in the summary where relevant.

Summarize the relevant first-person experiences, caregiver observations, questions and replies in whatever shape fits the discussion. Attribute claims by role and retain the exposure, outcome, adverse reports, uncertainty and disagreement when the thread supplies them. Label any inference and leave an uncertain diagnosis, dose or symptom type open. Skip unavailable fields. Mention repeat or cross-posted accounts when identifiable without copying handles, and distinguish suggestions from reported use. Votes and reply counts supply no clinical evidence or population estimate.

The Oracle shows these records under Culture & experience with a Conversation badge. Conversation summaries can guide follow-up searches and remain distinct from experimental verdicts.

Use the actual source publication date for the bucket, not an unsupported ancient attribution. A modern edition of a historical text belongs with that edition and records the older attribution separately. For an undated public source, use the first documented capture's period and label `Date basis: first documented capture; publication date unknown`; this is an archival placement, not a fabricated publication date.

Original documents earlier than 1865 belong in their actual five-year period, such as `1595-1599`, as historical context. Create only a period with an inspected source, its index and Observations; do not pad intervening centuries. Keep the original continuous 1865-onward series intact. Record corrected title-page dates, replacement leaves, edition uncertainty and transcript-only access. An early shaking or palsy recommendation does not establish a historical Parkinson diagnosis or centuries of verified benefit.

Traditional and personal accounts carry lower evidential weight for treatment effects than controlled human studies. A structured survey is observational research, not a randomized intervention. A laboratory mechanism, a repeated testimonial and an authentic traditional text also answer different questions. Do not attach arbitrary numerical weights or count repeated accounts as independent replications. Any experimental verdict still needs a source-level rationale, preparation and symptom fit, contrary evidence and the established confidence rules.

Cross-link formal studies already stored under `Source-Text/` instead of duplicating cohorts. A cultural record can point to a formal trial without inheriting its result for a different recipe, ceremony, dose or diagnosis. Sources outside the frozen experiment vocabulary remain valid catalog leads.

Keep personal identifiers out of curated public records. Summarize public individual experiences without copying participant names, handles, contact details or other unnecessary identifying information. Retain a suitable public source locator and paraphrase within source rights; raw working downloads belong in ignored build folders.

The Oracle text catalog and public model include these records. The browser presents source leads alongside experiment claims and labels unresolved claims and unreviewed questions. A word match supplies a lead, not a graded treatment finding.

Initialize the existing periods and verify every cultural text record with the native tool, from the repository root:

```powershell
New-Item -ItemType Directory -Force build/cultural-catalog/bin, build/cultural-catalog/units | Out-Null
fpc -B -Mdelphi -Sa -Cr -Co -Ci -gl -FUbuild/cultural-catalog/units -FEbuild/cultural-catalog/bin experiments/tools/research.culture.lpr
& ./build/cultural-catalog/bin/research.culture.exe (Get-Location).Path 2025
```

The final argument is the last bucket's starting year. The tool preserves existing category text and links, checks required source fields and chronological placement, and verifies reused accession paths. It also verifies existing pre-1865 cultural periods with a period index, rejecting malformed or shifted ranges; it does not create missing historical periods. File and metadata validation does not establish factual or clinical validity.
