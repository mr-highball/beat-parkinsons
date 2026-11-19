# Parkinson’s food thought experiment

This is a collection of 1,000 intentionally arbitrary hypotheses about food, herbs, spices, edible oils, and Parkinson’s symptoms. The wording records what the generator drew. The verdict and references record what the evidence review found.

[Experiment rules](AGENTS.md) · [Work record](WORK.md)

[Results manifest](manifest.md) · [Frozen claims](freeze.tsv) · [Verdict ledger](verdicts.tsv) · [Search coverage](claim-coverage.tsv)

[Follow-up investigation](followup/README.md) · [Evidence assessments](followup/assessments.tsv) · [Per-claim follow-up status](followup/claim-depth.tsv)

## Phase order

1. Define the vocabulary without reading the research archive or looking up evidence. Use only the vocabulary and seed to generate all 1,000 claims.
2. Verify the files and frozen hash before using the archive or sending research queries. Preserve the frozen claim fields during review.
3. Screen the local catalog and targeted external results. Keep evidence and search records linked to the original claims.
4. Apply the reviewed verdicts, verify the files and their links, then publish the manifest.

The project uses native Free Pascal. The current Windows build target is FPC 3.3.1, i386-win32. Build outputs and downloaded screening data belong under the ignored build directory.

## Reproduce the checks

Run these PowerShell commands from the repository root. Each build script accepts an explicit compiler override through the FPC environment variable.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-statements.ps1"
& "$experiment/tools/build-scan.ps1"
& "$experiment/tools/build-search.ps1"
& "$experiment/tools/build-review.ps1"

$statements = "$experiment/build/statements/3.3.1-i386-win32/bin/statement-tool.exe"
$review = "$experiment/build/food-experiment-review/i386-win32-3.3.1/bin/foodexperiment.review.exe"
& $statements verify $experiment
& $review verify $experiment
```

The generator takes a fresh experiment directory containing the two vocabulary files and an optional decimal seed. It refuses to overwrite the frozen experiment. To refresh the evidence run, verify the freeze first. A later search can return a different literature snapshot.

```powershell
$scan = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
$screen = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.screen.exe"
$search = "$experiment/build/search-3.3.1-i386-win32/bin/foodexperiment.search.exe"
& $scan scan $experiment research "$experiment/build/local-scan"
& $search search $experiment "$experiment/build/external-refresh" 8
& $screen $experiment "$experiment/build/local-scan" "$experiment/build/external-refresh" "$experiment/build/screen"
```

Review newly flagged sources and update [source dispositions](source-dispositions.tsv) and [reviewed claims](reviewed-claims.tsv) before passing the reviewed-claims path as the final argument to the screening tool. That command writes the final query and verdict ledgers. Publish the reviewed coverage TSVs and findings, then run the review tool’s apply, verify, and summary commands in that order. Keep the frozen files and seed as the common baseline for comparisons.

Those search commands reproduce the historical first-pass pipeline in a build directory. The [follow-up instructions](followup/README.md#reproducing-the-follow-up) cover the uncapped search and the resumable evidence ledgers.

For a follow-up expression ledger, the native ingredient search supports the documented [Europe PMC SOAP endpoint](https://dev.europepmc.org/SoapWebServices) if the default REST route fails. Run it with the same expressions and a separate output directory. The optional final `soap` argument selects the route, and `P_PDATE_D desc` supplies the SOAP publication-date sort. Both routes use the same query, pagination, and completion checks.

Rebuild the [native coverage and masked research queue](followup/coverage-current/README.md) as the live assessment ledger changes.
