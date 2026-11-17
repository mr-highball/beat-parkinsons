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

Use `oracle_status` to record the claim and catalog revisions. Use
`oracle_search_catalog` for identifiers and alternate terms. Open specific
research passages and the assessments needed to check evidence and conflicts.
Continue through relevant result pages and source trails when the question
requires it.
