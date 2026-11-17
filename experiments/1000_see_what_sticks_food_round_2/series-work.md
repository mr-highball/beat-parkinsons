# Pantry expansion evidence sequence

The six expansion rounds contain 5,930 frozen hypotheses. They have zero evidence reviews as of the series validation. Native generation and verification both passed. A separate run against a modified scratch reservation correctly rejected it.

The original experiment is first in the sequence. The six prepared rounds share one validated reservation and may be frozen without consulting evidence. Review only one round at a time. Resume unfinished work from its published manifest and ledgers. Open the next round after the preceding round has passed its coverage and evidence audit.

| Review order | Experiment | Handoff |
| --- | --- | --- |
| 1 | [Original](../1000_see_what_sticks_food/followup/README.md) | Active evidence review. Use its current masked queue, exact source queue and access trails. |
| 2 | [Round 2](README.md) | Queued after the original evidence audit. |
| 3 | [Round 3](../1000_see_what_sticks_food_round_3/README.md) | Queued after the round 2 evidence audit. |
| 4 | [Round 4](../1000_see_what_sticks_food_round_4/README.md) | Queued after the round 3 evidence audit. |
| 5 | [Round 5](../1000_see_what_sticks_food_round_5/README.md) | Queued after the round 4 evidence audit. |
| 6 | [Round 6](../1000_see_what_sticks_food_round_6/README.md) | Queued after the round 5 evidence audit. |
| 7 | [Round 7](../1000_see_what_sticks_food_round_7/README.md) | Queued after the round 6 evidence audit. |

Start each new evidence review by reading the completed experiments as an index. Use their manifest to locate findings, their claim–study assessments to locate sources, and their query, coverage, source-access and open-trail records to locate the relevant searches and missing material. Look up both ingredient and symptom, including aliases, across the earlier rounds. Record the earlier round and claim ID, the original study or registry key, local source anchor, reviewed preparation, endpoint, population, and original review depth. An earlier search receipt covers a new claim only when its expression and screened source context actually cover the new pair. The earlier verdict supplies context and carries no evidentiary weight by itself.

Trace each applicable entry to the original source or registry. Deduplicate reports of the same study and retain uncertain links. Continue the existing catalog-wide search, complementary providers and citation routes with explicit access limits. Add new evidence to the chronological research catalog by first public date and cite the local source. Preserve opposed and inconclusive evidence and continue relevant trails while they produce findings.

## Native reservation and freeze commands

Use PowerShell in the repository root. The original toolchain and frozen statements remain in their original directory. The shared series build writes temporary artifacts on the project drive.

```powershell
& ./experiments/tools/build-series.ps1 reserve
& ./experiments/tools/build-series.ps1 generate
& ./experiments/tools/build-series.ps1 verify
```

The reservation and generation commands verify an existing identical result before reusing it. The verifier replays the deterministic partition and the locked statement fields in all six rounds. The original evidence scripts retain assumptions about 1,000 claims and equal category quotas. Adapt those checks for variable counts and actual strata before round 2 evidence application. Verify source links, search coverage and verdicts during each evidence round.

[Native verification totals](series-validation.tsv) · [Shared reservation](series-pairs.tsv) · [Reservation validation](reservation-validation.md) · [Original live verdicts](../1000_see_what_sticks_food/manifest.md)
