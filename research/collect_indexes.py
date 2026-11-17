"""Refresh the five-year Parkinson's literature and study discovery indexes."""

import argparse
import csv
import html
import json
import re
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
FIRST_YEAR = 1865
LITERATURE_API = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
LITERATURE_QUERY = (
    'SRC:MED AND (TITLE_ABS:parkinson* OR TITLE_ABS:"paralysis agitans" '
    'OR TITLE_ABS:"shaking palsy" OR MESH:"Parkinson Disease")'
)
TRIAL_API = "https://clinicaltrials.gov/api/v2/studies"
TRIAL_QUERY = "Parkinson Disease"
PUBMED_API = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
ARCHIVAL_THROUGH = date(1944, 12, 31)
ARCHIVAL_QUERY = (
    'parkinson*[Title/Abstract] OR "paralysis agitans"[Title/Abstract] '
    'OR "paralysie agitante"[Title/Abstract] OR "shaking palsy"[Title/Abstract] '
    'OR "encephalitis lethargica"[Title] OR "post-encephalitic"[Title] '
    'OR "postencephalitic"[Title]'
)
LITERATURE_COLUMNS = (
    "first_publication_date", "pmid", "doi", "pmcid", "journal", "publication_types", "title"
)
TRIAL_COLUMNS = (
    "first_posted", "nct_id", "study_type", "phases", "status", "results_posted",
    "conditions", "interventions", "title"
)
ARCHIVAL_COLUMNS = ("publication_date_as_indexed", "pmid", "doi", "pmcid", "journal", "title")


def fetch_json(endpoint, parameters):
    url = f"{endpoint}?{urlencode(parameters)}"
    request = Request(url, headers={"Accept": "application/json"})
    for attempt in range(4):
        try:
            with urlopen(request, timeout=60) as response:
                return json.load(response)
        except HTTPError as error:
            if error.code not in (429, 500, 502, 503, 504) or attempt == 3:
                raise
            retry_after = error.headers.get("Retry-After", "")
            delay = int(retry_after) if retry_after.isdigit() else 2 ** (attempt + 1)
        except (URLError, TimeoutError):
            if attempt == 3:
                raise
            delay = 2 ** (attempt + 1)
        time.sleep(delay)


def bucket_label(year):
    start = FIRST_YEAR + ((year - FIRST_YEAR) // 5) * 5
    return f"{start}-{start + 4}"


def literature_rows(start, end):
    query = f"{LITERATURE_QUERY} AND FIRST_PDATE:[{start} TO {end}]"
    cursor = "*"
    rows = {}
    expected = None
    while True:
        page = fetch_json(LITERATURE_API, {
            "query": query, "format": "json", "resultType": "lite",
            "pageSize": 1000, "cursorMark": cursor,
        })
        if expected is None:
            expected = page["hitCount"]
        for item in page["resultList"]["result"]:
            published = date.fromisoformat(item["firstPublicationDate"])
            pmid = item["pmid"]
            if not start <= published <= end or pmid in rows or not pmid.isdigit():
                raise ValueError(f"Unexpected literature record {pmid} dated {published}")
            rows[pmid] = (
                published.isoformat(), pmid, item.get("doi"), item.get("pmcid"),
                item.get("journalTitle"), item.get("pubType"), item.get("title"),
            )
        next_cursor = page.get("nextCursorMark")
        if len(rows) >= expected or not next_cursor or next_cursor == cursor:
            break
        cursor = next_cursor
    if len(rows) != expected:
        raise ValueError(f"Europe PMC {start} to {end}: received {len(rows)} of {expected}")
    return sorted(rows.values())


def trial_rows(cutoff):
    query = f"AREA[StudyFirstPostDate]RANGE[{FIRST_YEAR}-01-01,{cutoff}]"
    fields = (
        "NCTId,BriefTitle,StudyFirstPostDate,OverallStatus,HasResults,StudyType,Phase,"
        "Condition,InterventionName"
    )
    parameters = {
        "query.cond": TRIAL_QUERY, "filter.advanced": query,
        "fields": fields, "countTotal": "true", "pageSize": 1000,
    }
    seen = set()
    rows = defaultdict(list)
    expected = None
    while True:
        page = fetch_json(TRIAL_API, parameters)
        if expected is None:
            expected = page["totalCount"]
        for item in page["studies"]:
            protocol = item["protocolSection"]
            ident = protocol["identificationModule"]
            status = protocol["statusModule"]
            design = protocol.get("designModule", {})
            nct_id = ident["nctId"]
            posted = date.fromisoformat(status["studyFirstPostDateStruct"]["date"])
            if nct_id in seen or not date(FIRST_YEAR, 1, 1) <= posted <= cutoff:
                raise ValueError(f"Unexpected registry record {nct_id} dated {posted}")
            seen.add(nct_id)
            interventions = protocol.get("armsInterventionsModule", {}).get("interventions", [])
            rows[bucket_label(posted.year)].append((
                posted.isoformat(), nct_id, design.get("studyType"),
                "; ".join(design.get("phases", [])), status.get("overallStatus"),
                str(item["hasResults"]).lower() if "hasResults" in item else "",
                "; ".join(protocol.get("conditionsModule", {}).get("conditions", [])),
                "; ".join(intervention["name"] for intervention in interventions if intervention.get("name")),
                ident.get("briefTitle"),
            ))
        token = page.get("nextPageToken")
        if not token:
            break
        if token == parameters.get("pageToken"):
            raise ValueError("ClinicalTrials.gov returned the same page token twice")
        parameters["pageToken"] = token
    if len(seen) != expected:
        raise ValueError(f"ClinicalTrials.gov: received {len(seen)} of {expected}")
    return {bucket: sorted(records) for bucket, records in rows.items()}


def archival_rows(cutoff):
    end = min(cutoff, ARCHIVAL_THROUGH)
    search = fetch_json(f"{PUBMED_API}/esearch.fcgi", {
        "db": "pubmed", "term": ARCHIVAL_QUERY, "retmode": "json", "retmax": 10000,
        "datetype": "pdat", "mindate": f"{FIRST_YEAR}/01/01",
        "maxdate": end.strftime("%Y/%m/%d"),
    })["esearchresult"]
    identifiers = search["idlist"]
    if len(identifiers) != int(search["count"]) or len(set(identifiers)) != len(identifiers):
        raise ValueError("PubMed archival search returned an incomplete or duplicate ID list")
    rows = defaultdict(list)
    for offset in range(0, len(identifiers), 100):
        batch = identifiers[offset:offset + 100]
        summaries = fetch_json(f"{PUBMED_API}/esummary.fcgi", {
            "db": "pubmed", "id": ",".join(batch), "retmode": "json",
        })["result"]
        for pmid in batch:
            item = summaries[pmid]
            published = item["pubdate"]
            year = int(published.split()[0])
            if not FIRST_YEAR <= year <= end.year:
                raise ValueError(f"Unexpected PubMed publication date {published} for PMID {pmid}")
            ids = {identifier["idtype"]: identifier["value"] for identifier in item["articleids"]}
            rows[bucket_label(year)].append((
                published, pmid, ids.get("doi"), ids.get("pmc"), item.get("source"), item.get("title"),
            ))
        time.sleep(0.34)
    return {bucket: sorted(records) for bucket, records in rows.items()}


def clean_cell(value):
    if value is None:
        return ""
    value = re.sub(r"</?(?:i|b|em|strong|sub|sup)>", "", value)
    return " ".join(html.unescape(value).split())


def write_tsv(path, columns, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tsv.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(columns)
        writer.writerows(tuple(map(clean_cell, row)) for row in rows)
    temporary.replace(path)


def write_coverage(output, manifest):
    write_tsv(
        output / "Index-Coverage.tsv",
        ("bucket", "start", "through", "literature_records", "registered_studies"),
        manifest,
    )


def collect_bucket(output, trials, start, end):
    label = bucket_label(start.year)
    literature = literature_rows(start, end)
    registry = trials.get(label, [])
    directory = output / label
    write_tsv(directory / "Literature-Index.tsv", LITERATURE_COLUMNS, literature)
    write_tsv(directory / "Study-Registry.tsv", TRIAL_COLUMNS, registry)
    print(f"{label}: {len(literature)} literature records, {len(registry)} registrations", flush=True)
    return label, start.isoformat(), end.isoformat(), str(len(literature)), str(len(registry))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--through", type=date.fromisoformat, required=True)
    parser.add_argument("--output", type=Path, default=ROOT)
    parser.add_argument("--archival-only", action="store_true", help="Refresh the pre-1945 PubMed supplement")
    args = parser.parse_args()
    if args.through.year < FIRST_YEAR:
        parser.error(f"--through must be in or after {FIRST_YEAR}")

    archival = archival_rows(args.through)
    for label, records in archival.items():
        write_tsv(args.output / label / "Archival-PubMed.tsv", ARCHIVAL_COLUMNS, records)
    print(f"Archival PubMed supplement: {sum(map(len, archival.values()))} records", flush=True)
    if args.archival_only:
        return

    trials = trial_rows(args.through)
    with ThreadPoolExecutor(max_workers=4) as pool:
        collections = [
            pool.submit(
                collect_bucket, args.output, trials, date(year, 1, 1),
                min(args.through, date(year + 4, 12, 31)),
            )
            for year in reversed(range(FIRST_YEAR, args.through.year + 1, 5))
        ]
        manifest = sorted(collection.result() for collection in collections)
    write_coverage(args.output, manifest)


if __name__ == "__main__":
    main()
