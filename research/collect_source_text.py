"""Collect reusable PMC article text for the Parkinson's research archive."""

import argparse
import csv
import hashlib
import json
import re
import time
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from http.client import HTTPSConnection, HTTPException
from pathlib import Path
from threading import local
from urllib.parse import parse_qs, unquote, urlencode, urlsplit

from collect_indexes import LITERATURE_API, LITERATURE_QUERY, ROOT, fetch_json, write_tsv


CLOUD = "pmc-oa-opendata.s3.amazonaws.com"
LICENSES = {"CC0", "CC BY", "CC BY-SA"}
LICENSE_SEARCH = "(LICENSE:cc0 OR LICENSE:cc-by OR LICENSE:cc-by-sa)"
MANIFEST = "PMC-Text-Retrieval.tsv"
MANIFEST_FIELDS = ("pmcid", "retrieval_status", "license", "version")
THREAD = local()
PMCID = re.compile(r"PMC\d+")


def read_tsv(path):
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def get_object(path, missing_ok=False):
    for attempt in range(4):
        try:
            if not hasattr(THREAD, "connection"):
                THREAD.connection = HTTPSConnection(CLOUD, timeout=30)
            THREAD.connection.request("GET", path)
            response = THREAD.connection.getresponse()
            data = response.read()
            if response.status == 200:
                return data
            if response.status in (403, 404) and missing_ok:
                return None
            if response.status not in (429, 500, 502, 503, 504):
                raise ValueError(f"PMC Cloud HTTP {response.status}")
            error = ValueError(f"PMC Cloud HTTP {response.status}")
        except (OSError, HTTPException) as failure:
            error = failure
        THREAD.connection.close()
        del THREAD.connection
        if attempt == 3:
            raise error
        time.sleep(2 ** attempt)


def read_version(pmcid, version):
    data = get_object(f"/metadata/{pmcid}.{version}.json", missing_ok=True)
    if data is None:
        return {}
    record = json.loads(data)
    if record.get("pmcid") != pmcid or str(record.get("version")) != str(version):
        raise ValueError("PMC Cloud returned metadata for the wrong article version")
    return record


def license_code(metadata):
    return (metadata.get("license_code") or "").upper().replace("CC0 1.0", "CC0")


def eligible(record):
    return license_code(record) in LICENSES and bool(record.get("text_url"))


def select_version(pmcid):
    first = read_version(pmcid, 1)
    if eligible(first) and not first.get("is_manuscript"):
        return first
    query = urlencode({"list-type": "2", "prefix": f"{pmcid}.", "delimiter": "/"})
    document = ET.fromstring(get_object(f"/?{query}"))
    records = [first] if first else []
    for prefix in document.findall("{*}CommonPrefixes/{*}Prefix"):
        match = re.fullmatch(rf"{pmcid}\.(\d+)/", prefix.text or "")
        if match and match[1] != "1":
            record = read_version(pmcid, int(match[1]))
            if record:
                records.append(record)
    licensed = [record for record in records if eligible(record)]
    if licensed:
        return max(licensed, key=lambda record: (not record.get("is_manuscript"), record["version"]))
    return max(records, key=lambda record: record["version"], default={})


def save_text(path, metadata):
    pmcid, version = metadata["pmcid"], metadata["version"]
    asset = urlsplit(metadata["text_url"])
    expected_path = f"/{pmcid}.{version}/{pmcid}.{version}.txt"
    if (asset.scheme, asset.netloc, asset.path) != ("s3", "pmc-oa-opendata", expected_path):
        raise ValueError("PMC Cloud text URL does not identify the selected article")
    body = get_object(asset.path)
    expected_md5 = parse_qs(asset.query).get("md5", [""])[0]
    if not expected_md5 or hashlib.md5(body).hexdigest() != expected_md5:
        raise ValueError("PMC Cloud article text checksum mismatch")
    body.decode("utf-8")
    if not body.strip():
        raise ValueError("PMC Cloud article text is empty")
    header = [
        f"Title: {metadata['title']}",
        f"Source: https://pmc.ncbi.nlm.nih.gov/articles/{pmcid}/",
        f"Text object: https://{CLOUD}{asset.path}",
        "Data source: U.S. National Library of Medicine, PMC Cloud Service",
        f"PMCID: {pmcid}",
        f"PMID: {metadata.get('pmid') or ''}",
        f"DOI: {metadata.get('doi') or ''}",
        f"Citation: {metadata.get('citation') or ''}",
        f"License: {license_code(metadata)} (article license statement below)",
        f"Version: {version}",
        f"Retracted in PMC metadata: {'yes' if metadata.get('is_retracted') else 'no'}",
        "Text coverage: article text",
        "Format: NLM plain-text extraction. This provenance header was added.",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".txt.tmp")
    temporary.write_bytes(("\n".join(header) + "\n\n").encode("utf-8") + body)
    temporary.replace(path)


def download(root, pmcid, bucket):
    path = root / bucket / "Source-Text" / f"{pmcid}.txt"
    if path.is_file():
        with path.open(encoding="utf-8") as stream:
            header = dict(line.rstrip().split(": ", 1) for line in [stream.readline() for _ in range(13)]
                          if ": " in line)
        return pmcid, "text_available", header["License"].split(" (", 1)[0], header["Version"]
    try:
        metadata = select_version(pmcid)
        license = license_code(metadata)
        version = str(metadata.get("version", ""))
        if not eligible(metadata):
            return pmcid, "no_eligible_version", license, version
        save_text(path, metadata)
        return pmcid, "text_available", license, version
    except (OSError, HTTPException, ValueError, KeyError, ET.ParseError) as error:
        print(f"{pmcid} {type(error).__name__}: {error}", flush=True)
        return pmcid, "download_error", "", ""


def lookup_indexes(root, coverage):
    by_pmcid, by_pmid, by_doi = {}, {}, {}
    for period in coverage:
        bucket = period["bucket"]
        for name in ("Literature-Index.tsv", "Archival-PubMed.tsv"):
            path = root / bucket / name
            if not path.is_file():
                continue
            for row in read_tsv(path):
                pmcid = row["pmcid"]
                if PMCID.fullmatch(pmcid):
                    by_pmcid.setdefault(pmcid, bucket)
                    by_pmid[row["pmid"]] = pmcid
                    if row["doi"]:
                        by_doi[row["doi"].lower()] = pmcid
    return by_pmcid, by_pmid, by_doi


def annotated_targets(root, coverage, indexes):
    by_pmcid, by_pmid, by_doi = indexes
    targets = {}
    for period in coverage:
        bucket = period["bucket"]
        for page in sorted((root / bucket).glob("*.md")):
            if page.name == "README.md":
                continue
            for url in re.findall(r"\]\((https?://[^)\s]+)\)", page.read_text(encoding="utf-8")):
                parsed = urlsplit(unquote(url))
                match = PMCID.search(parsed.path) if parsed.hostname == "pmc.ncbi.nlm.nih.gov" else None
                if match:
                    pmcid = match[0]
                elif parsed.hostname == "pubmed.ncbi.nlm.nih.gov":
                    pmcid = by_pmid.get(parsed.path.strip("/"))
                else:
                    doi = re.search(r"10\.\d{4,9}/[^\s?#]+", parsed.path)
                    pmcid = by_doi.get(doi[0].rstrip("/").lower()) if doi else None
                    if parsed.hostname == "www.nature.com" and parsed.path.startswith("/articles/"):
                        pmcid = by_doi.get(f"10.1038/{parsed.path.split('/')[2]}") or pmcid
                if pmcid:
                    targets.setdefault(pmcid, by_pmcid.get(pmcid, bucket))
    return targets


def discover(period, wanted, pmc_by_pmid):
    if not wanted:
        return {}
    bucket = period["bucket"]
    query = f"{LITERATURE_QUERY} AND {LICENSE_SEARCH} AND FIRST_PDATE:[{period['start']} TO {period['through']}]"
    cursor = "*"
    candidates = {}
    seen = set()
    expected = None
    while True:
        page = fetch_json(LITERATURE_API, {
            "query": query, "format": "json", "resultType": "lite",
            "pageSize": 1000, "cursorMark": cursor,
        })
        if expected is None:
            expected = page["hitCount"]
        for row in page["resultList"]["result"]:
            seen.add(row["pmid"])
            pmcid = row.get("pmcid") or pmc_by_pmid.get(row["pmid"])
            if pmcid in wanted:
                candidates[pmcid] = bucket
        next_cursor = page.get("nextCursorMark")
        if len(seen) >= expected or not next_cursor or next_cursor == cursor:
            break
        cursor = next_cursor
    if len(seen) != expected:
        raise ValueError(f"{bucket}: Europe PMC returned {len(seen)} of {expected} results")
    return candidates


def save_manifest(root, manifest):
    write_tsv(root / MANIFEST, MANIFEST_FIELDS, sorted(manifest.values()))


def collect_batch(root, pool, targets, manifest, pending):
    for pmcid, bucket in targets.items():
        if pmcid not in pending and manifest.get(pmcid, ("", ""))[1] not in {
            "text_available", "no_eligible_version"
        }:
            pending[pmcid] = pool.submit(download, root, pmcid, bucket)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--scope", choices=("annotated", "all"), default="all")
    parser.add_argument("--workers", type=int, default=24)
    args = parser.parse_args()
    if not 1 <= args.workers <= 48:
        parser.error("--workers must be from 1 to 48")
    root = args.root
    coverage = read_tsv(root / "Index-Coverage.tsv")
    indexes = lookup_indexes(root, coverage)
    annotated = annotated_targets(root, coverage, indexes)
    manifest = {}
    if (root / MANIFEST).is_file():
        for row in read_tsv(root / MANIFEST):
            pmcid = row["pmcid"]
            manifest[pmcid] = tuple(row[field] for field in MANIFEST_FIELDS)
            if row["retrieval_status"] == "text_available":
                bucket = indexes[0].get(pmcid) or annotated.get(pmcid)
                if not bucket or not (root / bucket / "Source-Text" / f"{pmcid}.txt").is_file():
                    del manifest[pmcid]
    wanted = defaultdict(set)
    for pmcid, bucket in indexes[0].items():
        wanted[bucket].add(pmcid)

    with ThreadPoolExecutor(max_workers=args.workers) as downloads:
        pending = {}
        print(f"{len(annotated)} annotated PMC articles matched by identifier", flush=True)
        collect_batch(root, downloads, annotated, manifest, pending)
        discovery_errors = []
        if args.scope == "all":
            with ThreadPoolExecutor(max_workers=4) as discovery:
                periods = {discovery.submit(discover, period, wanted[period["bucket"]], indexes[1]): period["bucket"]
                           for period in reversed(coverage) if wanted[period["bucket"]]}
                for result in as_completed(periods):
                    try:
                        targets = result.result()
                    except (OSError, ValueError, KeyError) as error:
                        discovery_errors.append(periods[result])
                        print(f"{periods[result]} discovery failed: {error}", flush=True)
                    else:
                        print(f"{periods[result]}: {len(targets)} literature candidates", flush=True)
                        collect_batch(root, downloads, targets, manifest, pending)
        for number, result in enumerate(as_completed(pending.values()), 1):
            row = result.result()
            manifest[row[0]] = row
            if number % 1000 == 0:
                print(f"Processed {number:,}/{len(pending):,} PMC downloads", flush=True)
                save_manifest(root, manifest)
    save_manifest(root, manifest)
    print(dict(Counter(row[1] for row in manifest.values())), flush=True)
    if discovery_errors or any(row[1] == "download_error" for row in manifest.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
