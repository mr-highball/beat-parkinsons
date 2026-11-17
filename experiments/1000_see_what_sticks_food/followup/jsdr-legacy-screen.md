# Japanese swallowing proceedings before the public abstract backfile

MedicalOnline exposes public tables of contents for 14 issues containing reports from the 1995–2010 meetings, including two 1999 issues with overlapping content. The native screen reconciled all **4,167 TOC rows** and saved the byte count and SHA-256 of every raw EUC-JP response. Rows include regular articles, meeting titles and administrative material. The count represents TOC appearances. For example, the 1999 Nozaki title appears with the same authors on different pages in two issues. The 2010 translated Troche item points to an English paper with the same cohort. [Issue inventory](jsdr-legacy-issues.tsv) · [Capture hashes](jsdr-legacy-issue-audit.tsv) · [All TOC rows](jsdr-legacy-toc.tsv) · [Official journal index](https://mol.medicalonline.jp/archive/select?jo=cb5dvsph)

The tables display 4,165 abstract links, one download-only item and one row with no item link. All **71 flagged links** redirected to member login when tested. The reviews pair each exact TOC key and source URL with the closest public body or a reason the match remains limited to a title. A related public paper is identified as a separate report whenever sample identity is uncertain. [Exact review keys](jsdr-legacy-review-keys.tsv) · [Title dispositions](jsdr-legacy-reviews.tsv) · [Item access probes](jsdr-legacy-access.tsv)

## Ingredient and diagnosis screening

The title screen flagged Parkinson and related diagnoses, tubers, chili or pepper, and levodopa-related dietary components. The second pass added 12 titles with an ingredient and a swallowing term beyond those flags. Six were substring artifacts, including kale inside the Japanese transliteration of “scale” and shrimp inside the place name Ebina. The other six included thickened catechin green tea, a milk and water comparison, baked banana, and two yogurt titles. The frozen overlay matched all 1,000 claims against 50 diagnosis-flagged titles. None of those 50 had an exact frozen ingredient alias. The 2006 title naming candy and dried squid still has a contextual disposition. [Base vocabulary](jsdr-topic-vocabulary.tsv) · [Additional topics](jsdr-legacy-extra-topics.tsv) · [Diagnosis title matches](jsdr-legacy-claim-title-matches.tsv) · [Coverage by claim](jsdr-legacy-claim-coverage.tsv)

## Recovered primary evidence

- In Nagaya's 2004 series, 13 of 25 people with Parkinson’s aspirated sugar-water contrast from a cup. None of those 13 aspirated contrast jelly from a spoon during the test. The design changed both texture and administration and measured immediate imaging outcomes. [Dated primary source](../../../research/2000-2004/Food-Experiment-JSDR-Legacy-Early.md#2004-comparison-of-contrast-jelly-with-sugar-water)
- A published follow-up to a 2007 presentation tracked juice and jelly in one person with Parkinson’s. Juice aspirated at baseline and still penetrated the larynx after metronome rehabilitation, although aspiration was absent on that examination. The same test food can show different outcomes during rehabilitation. [Dated primary source](../../../research/2005-2009/Food-Experiment-JSDR-Legacy-Middle.md#jelly-and-juice-during-rhythmic-swallowing-training-in-parkinsons-disease)
- A Japanese ministry annex preserved Yamasaki and colleagues’ 2009 letter. The 12 older aspiration-pneumonia patients had a mean reflex latency of 16.3 seconds after water and 6.1 seconds after the highest capsiate concentration. The experiment delivered an extract by pharyngeal catheter and reported no Parkinson subgroup. A later capsinoid seasoning project used a different preparation and measured swallowing movements during imaging. [2009 letter and route](../../../research/2005-2009/Food-Experiment-JSDR-Legacy-Later.md#2009-capsiate-and-swallow-reflex-in-older-people) · [2015 grant results](../../../research/2015-2019/Food-Experiment-JSDR-Legacy-Later.md#2015-ch-19-sweet-seasoning-on-a-videofluoroscopy-jelly)
- A 2016 conference report followed five patients described as having Parkinson’s with Lewy body dementia after repeated exposure to the aroma of black pepper oil. Two improved on the reported swallowing tests, one remained unchanged and two dropped out. There was no control and the abstract gives no raw scores. The cracked black pepper ingestion claim remains open. [Dated primary source](../../../research/2015-2019/Food-Experiment-JSDR-Legacy-Later.md#2016-inhaled-black-pepper-oil-and-swallowing-in-parkinson-with-lewy-body-dementia)

## Replay

Save the 14 issue pages from the audit URLs as `<issue_key>.html` in the capture directory. Fetch each public issue page directly and preserve the original byte encoding. The FPC tool uses the Windows MLang converter for EUC-JP, rejects replacement characters and reconciles the exact expected row count for each issue. The audit writes the capture hashes for comparison with the versioned ledger. Changes to the provider snapshot require reconciliation before replacing the original coverage.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$followup = "$experiment/followup"
$capture = "$experiment/build/jsdr-legacy"
$bin = "$experiment/build/followup-3.3.1-i386-win32/bin"
& "$bin/foodexperiment.jsdr.exe" legacy "$followup/jsdr-legacy-issues.tsv" $capture $experiment $followup
if ($LASTEXITCODE) { throw "Legacy TOC replay failed" }
& "$bin/foodexperiment.crossref.exe" audit-topics "$capture/review-keys.tsv" "$capture/reviews.tsv" "$followup/jsdr-legacy-reviews.tsv"
```

The early standalone abstract books and member-only text remain open. The public TOCs cannot establish which foods and symptoms appeared solely in abstract bodies. Follow public author deposits, grant annexes, conference versions, and print holdings. [Earlier holdings and remaining gaps](jsdr-proceedings-screen.md) · [Open trail ledger](open-trails.tsv)
