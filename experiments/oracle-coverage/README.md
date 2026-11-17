# Oracle research coverage

[First-pass lookups](lookups.tsv) · [Batch rates and priorities](batches.tsv)

Make one first-pass record for each distinct evidence question in a batch. An
ingredient and symptom question belongs to `claim_evidence`. Retrieval or
verification of a defined paper, trial, or collection belongs to
`source_verification`. Record the actual query terms and any local citations.
Alias searches, extra result pages, and repeat checks after catalog expansion
belong to the same question and do not add denominator rows.

| Outcome | Meaning |
| --- | --- |
| `hit` | Verified local evidence answers the assigned question at the required depth. Evidence in either direction or a conclusive eligibility exclusion can qualify. |
| `partial` | A local lead exists, with a material gap in exposure, preparation, population, endpoint, data, or source access. |
| `miss` | Relevant local searches completed without a usable lead for the assigned question. |
| `unavailable` | The lookup could not be evaluated because the oracle or index was unavailable, stale, or unreadable for the relevant material. |

Strict hit rate is `hits / (hits + partials + misses)`. Lead rate also counts
partials in the numerator. Record both with their counts. Keep unavailable
questions visible outside the rate and investigate those failures independently.
When an oracle lookup repeatedly stalls, use the same queries against the
native server and the affected transport to locate the delay. Compare source
identifiers, broader terms and paged results on the same catalog snapshot.
Address measured bottlenecks and verify result order, totals and coverage
diagnostics before recording an improvement.

Compare matching workstream and question types, then inspect exposure and symptom
groups. A declining rate calls for review of the underlying gaps and sample size.
When comparable batches keep declining, move recurring catalog gaps up the
research queue. Keep reporting unresolved questions and access limits regardless
of the local hit rate.

Dexter records the initial result before adding new evidence. After integrating
new sources into their chronological buckets, refresh the index and verify
retrieval. Use batch summaries to identify the gaps that motivate that work.
Record only research identifiers and relative source paths.

## Local launcher

Use the project's direct MCP tools when they are visible. Otherwise launch the
same server from the repository root and select the fields needed for the
assignment. This example checks the local evidence ledger for an exact pair.

```powershell
$Request = @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'oracle_query'
        arguments = @{ ingredient = 'black tea'; symptom = 'tremors'; scope = 'assessed'; limit = 3 }
    }
}
$Reply = $Request | ConvertTo-Json -Depth 6 -Compress |
    pwsh -NoProfile -File ./experiments/tools/parkinsons-oracle/serve.ps1 |
    ConvertFrom-Json
$Reply.result.content[0].text | ConvertFrom-Json
```

Use `oracle_status` to record the claim and catalog revisions. For a batch of
known study identifiers, call `oracle_find_sources` with, for example,
`identifiers: ["PMID:40647065", "NCT04986982"]`. Open the returned source
passages to verify identity, eligibility and depth. When archive matches are
empty, use `oracle_search_catalog` to find citations and catalog notes before
classifying a question. Use the text search for alternate terms, then review the
assessments needed to check evidence and conflicts.
If a focused follow-up already identifies a study in the claim ledger, pass
its exact `assessment_study` key to `oracle_claim` without paging. The result
includes every row for that key and the claim-wide verdict and coverage.
Zero matching rows means the key is absent from that claim's ledger at the
returned revision. Use the catalog and source checks for the underlying study.
When triaging an evidence-heavy claim, start with `oracle_claim` and
`assessment_limit: 8`. Pass each returned `next_assessment_offset` as
`assessment_offset` to continue on the same revision. Restart from the first
page if the revision changes. The first page follows ledger order. Use the full
response when reviewing all assessments and continue related source trails.

When the workspace is opened through a filesystem link, launch the script from
the checkout that owns the index. A catalog binding error can occur if the
launcher is called through a different path to that checkout. Use
`oracle_status` to verify the catalog before recording a source miss.

If the launcher stalls and the local oracle web server is already running,
use its loopback adapter for the same read-only lookup. Record the transport
failure separately from the catalog result so a successful fallback counts
only once.

```powershell
$Body = @{ name = 'oracle_search_catalog'; arguments = @{ terms = '3762195'; limit = 3 } } |
    ConvertTo-Json -Depth 4 -Compress
Invoke-RestMethod 'http://127.0.0.1:8795/api/oracle' -Method Post -ContentType 'application/json' -Body $Body
```
