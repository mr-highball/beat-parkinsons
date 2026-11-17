# Europe PMC HTTPS recovery

The original WinHTTP collector got HTTP 503 for all 24 masked expressions at page sizes 1,000 and 25. Tests of a literal or omitted initial cursor still failed through WinHTTP. The existing query program recovered all responses with a build-only FPC transport adapter invoking installed Windows curl for HTTPS. The exact Europe PMC REST endpoint, query expressions, order, identifiers and FPC count and pagination checks were retained. The subsequent native replay identified an unexpected Windows command-line argument for the optional sort field. With the documented omit-sort placeholder, the standard WinHTTP path reproduces the same complete results. [Primary query receipts](europe-pmc-queries.tsv) · [Large-page corroboration](europe-pmc-replay-page1000.tsv) · [Eight-page cursor receipt](europe-pmc-cursor-fixture.tsv) · [Eight returned appearances](europe-pmc-cursor-memberships.tsv) · [Provider documentation](https://europepmc.org/RestfulWebService)

The build-only adapter is in the experiment build directory under `masked-twenty-second-nov16/blimbo/provider-recovery/src`. It replaces the `foodexperiment.https` unit in a copy of `foodexperiment.ingredients.lpr` and keeps provider-response validation in FPC. URLs and cursor states were passed through the installed HTTPS transport. Binary and raw working files remain in the ignored build directory.

## Native confirmation

Windows passed a literal quotation mark to the optional sort field in the initial command. A focused diagnostic reproduced the resulting sort parameter. Using the collector's `-` placeholder for both prior output and sort removed the malformed parameter. The ordinary native WinHTTP collector then retrieved 24 complete expressions with 17 source rows. The SHA-256 of the confirmed result table exactly matches the previously published table. The original error receipts remain available for provenance. [Native confirmation](europe-pmc-winhttp-confirmation.tsv) · [Original result table](europe-pmc-memberships.tsv)

The command from the repository root uses these final arguments. Replace the two paths with the desired input and output locations.

    foodexperiment.ingredients.exe EXPRESSIONS.tsv OUTPUT_DIR 2 expressions - - 25
