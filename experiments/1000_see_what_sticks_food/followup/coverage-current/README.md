# Live-ledger coverage and masked research queue

Run from the repository root.

    & ./experiments/1000_see_what_sticks_food/tools/build-coveragequeue.ps1

The build accepts the FPC environment variable or an explicit Compiler argument. It puts the native binary, compiler receipt and replay outputs under the experiment's ignored build directory. The replay verifies the freeze hash and identities, uses the current verdict and assessment ledgers, and reads the lexical and archive counters from the latest depth snapshot. Assessment counts in the depth snapshot can lag the live evidence ledger.

The queue includes every Unknown claim without a nonpending assessment. Unassessed claims rank ahead of pending-only claims, then by the number of open claims for the ingredient and stable ingredient and ID order. For initial search design, use the direction-masked queue and keep the frozen preparation and symptom exact. Continue beyond the queue when an assessed claim has credible open trails. Each exposed search, paper or registry needs its own contextual disposition.

The current snapshot verifies at least one nonpending assessment for every frozen claim. The 5,009-row study ledger includes indirect sources. The completed depth snapshot used 2,776 assessment rows. Having an assessment does not mean exhaustive research is complete. [Category and direction coverage](coverage-strata.tsv) · [Gap totals](assessment-gaps.tsv) · [Masked queue](claim-gap-queue-masked.tsv) · [Full claim queue](claim-gap-queue.tsv) · [Input fingerprints](input-sha256.tsv) · [Broader bias audit](../coverage-bias-2026-11-15/README.md)
