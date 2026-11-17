# Movement Disorder Society 2026 attachment screen

The 2,072-body congress inventory names 1,860 distinct attachment URLs across 745 presentations. All 1,860 returned image data, with 1,858 distinct content hashes and 1,124,755,076 bytes across the URL inventory. Eleven attachments required a second collection pass. Some publisher filenames have the wrong extension for their payload, including TIFF files served at PNG URLs. The collector verifies PNG, JPEG and TIFF signatures and records the byte count and SHA-256 for each source. An offline replay reproduced the retrieval ledger byte for byte. [Body inventory](mds-2026-inventory.tsv) · [Attachment retrieval inventory](mds-2026-attachment-inventory.tsv)

The native Free Pascal reader uses Windows OCR with the `en-US` recognizer. Windows supplies the image decoder. The reader places images with transparency over white, enumerates all frames, and processes images larger than the OCR engine’s dimensions in overlapping original-resolution crops. The transparency correction recovered a clinical characteristics table from a PNG that the previous pass treated as blank. Each attachment has separate retrieval and extraction statuses. OCR can miss small labels, non-English text, symbols and data encoded in a chart. Contextual review checks original figures for credible food or symptom results. [Windows OCR documentation](https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr.ocrengine) · [Windows imaging documentation](https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/imaging) · [Original clinical characteristics table](https://www.mdsabstracts.org/wp-content/uploads/2026/09/0988_1474_002832_1.png)

The attachment screen uses the same topic and frozen claim vocabularies as the abstract screen. A separate index joins recognized attachments to their original presentation text. The join can surface a food named in an image and a symptom named in the abstract. It can also create co-occurrences across unrelated parts of the presentation, so each additional pair needs contextual assessment.

The transparency-corrected replay recognized text in 1,781 images. Seventy-nine images returned no recognized text, and none failed extraction. The correction restored text in 12 previously blank images. The OCR screen returned 65 topic flags and 36 ingredient flags, with 90 distinct images across their union. All 90 have exact-key contextual reviews. The joined screen covers 723 presentations with recognized attachments. Six presentations added 20 lexical claim pairs compared with their abstract bodies, across 19 frozen statements. Their reviews distinguish color legends, a software prototype, separate survival predictors, and formulations in a systematic review. [Extraction inventory](mds-2026-attachment-ocr.tsv) · [Topic screen](mds-2026-attachment-topic-screen.tsv) · [Image lexical screen](mds-2026-attachment-lexical-screen.tsv) · [Image reviews](mds-2026-attachment-ocr-reviews.tsv) · [Joined screen](mds-2026-attachment-joined-lexical.tsv) · [Joined reviews](mds-2026-attachment-joined-reviews.tsv)

An independent offline replay reproduced the extraction ledger SHA-256 `0de9370f71d689a6f6e975bc785ceb47ce2a1e610b47a2e33bfcc980632bef7e` and OCR index SHA-256 `d13e94f7bc1ff8d4f40077ad71d6ba860c2355f7532db78bf93d500f533ae8fe`. Both screens have a coverage row for each of the 1,000 frozen claims. [Image claim coverage](mds-2026-attachment-claim-coverage.tsv) · [Joined claim coverage](mds-2026-attachment-joined-claim-coverage.tsv) · [Additional source reviews](mds-2026-attachment-source-reviews.tsv)

All 79 originals that returned no OCR text have a visual disposition. One contains a QR code leading to a restricted folder. The abstract describes a neurological examination video for glutaric acidemia type 1 and gives no named food or swallowing task. The original image was reviewed and the linked video remains unverified. [Visual reviews](mds-2026-attachment-no-text-reviews.tsv) · [QR destination](https://drive.google.com/drive/folders/1qlU1K2YVfypfMsGbGPYqcis29CqMiIM5)

The cache stores raw publisher images and derived OCR inside the ignored build directory. The published inventory, screening results and contextual reviews identify source images by URL and by the SHA-256 of that URL. New evidence is summarized in its first-publication period. Eligible source texts are saved under the period’s `Source-Text` folder.

## Replay

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$followup = "$experiment/followup"
$cache = "$experiment/build/mds-2026"
$screen = "$cache/attachment-replay"
$ocr = "$cache/ocr-v3"
New-Item -ItemType Directory -Force $screen | Out-Null
& "$experiment/tools/build-followup.ps1"
& "$experiment/tools/build-scan.ps1"
$native = "$experiment/build/followup-3.3.1-i386-win32/bin"
$scan = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
& "$native/foodexperiment.mdsassets.exe" collect "$followup/mds-2026-inventory.tsv" "$cache/assets" "$screen/assets.tsv"
& "$native/foodexperiment.mdsassets.exe" replay "$followup/mds-2026-inventory.tsv" "$cache/assets" "$screen/replay.tsv"
& "$native/foodexperiment.mdsocr.exe" "$screen/assets.tsv" "$cache/assets" $ocr en-US
& $scan scan-topics "$ocr/index.tsv" "$followup/mds-2026-topics.tsv" "$screen/topics.tsv"
& $scan scan-index $experiment "$ocr/index.tsv" "$followup/hal-lexical-vocabulary.tsv" "$screen/lexical.tsv"
& "$native/foodexperiment.mds.exe" replay "$cache/title" "$screen/body"
& "$native/foodexperiment.mdsocr.exe" join "$screen/body/abstracts.tsv" "$ocr/index.tsv" "$screen/joined.tsv"
& $scan scan-index $experiment "$screen/joined.tsv" "$followup/hal-lexical-vocabulary.tsv" "$screen/joined-lexical.tsv"
& "$native/foodexperiment.mds.exe" audit "$screen/topics.tsv" "$screen/lexical.tsv" "$followup/mds-2026-attachment-ocr-reviews.tsv"
& "$native/foodexperiment.mdsocr.exe" delta "$followup/mds-2026-lexical-screen.tsv" "$screen/joined-lexical.tsv" "$followup/mds-2026-attachment-joined-reviews.tsv"
& "$native/foodexperiment.mdsocr.exe" audit-no-text "$ocr/ocr.tsv" "$followup/mds-2026-attachment-no-text-reviews.tsv"
```

Use a new screen directory for a repeat run and an OCR cache tied to one Windows OCR engine build. Exit code 2 from a retrieval, OCR or review audit denotes unresolved rows and preserves its ledger.
