"""Catalog citations and their locally collected text without network access."""

import argparse
import csv
import os
import re
import stat
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from itertools import islice
from pathlib import Path
from urllib.parse import unquote, urlsplit, urlunsplit


ROOT = Path(__file__).resolve().parent
SOURCE_DIR = "Source-Text"
INDEXES = ("Literature-Index.tsv", "Archival-PubMed.tsv")
BUCKET = re.compile(r"\d{4}-\d{4}")
PMC_ID = re.compile(r"PMC\d+", re.IGNORECASE)
NCT_ID = re.compile(r"NCT\d{8}", re.IGNORECASE)
DOI = re.compile(r"10\.\d{4,}/\S+", re.IGNORECASE)
HEADING = re.compile(r"^#{2,6}\s+(.+)$")
LINK = re.compile(r"\[([^\]\n]*)\]\((<https?://[^>\n]+>|https?://(?:[^\s()]+|\([^()\s]*\))+)\)")
STATUS_FIELDS = ("text_status", "text_coverage", "text_path")
ID_FIELDS = ("pmid", "pmcid", "doi")
ANNOTATED_ID_FIELDS = (*ID_FIELDS, "nct_id")


@dataclass(frozen=True)
class Citation:
    pmid: str
    pmcid: str
    doi: str
    index_names: tuple

    def identifiers(self):
        return {field: getattr(self, field) for field in ID_FIELDS if getattr(self, field)}


@dataclass(frozen=True)
class TextDocument:
    path: Path
    identifiers: dict
    urls: tuple
    coverage: str


def url_key(url):
    parts = urlsplit(url)
    host = (parts.hostname or "").lower()
    path = unquote(parts.path)
    if host == "pubmed.ncbi.nlm.nih.gov":
        match = re.fullmatch(r"/(\d+)/?", path)
        if match:
            return "pmid", match[1]
    if host in {"pmc.ncbi.nlm.nih.gov", "www.ncbi.nlm.nih.gov", "ncbi.nlm.nih.gov"}:
        match = re.match(r"^/(?:pmc/)?articles/(PMC\d+)(?:/|$)", path, re.IGNORECASE)
        if match:
            return "pmcid", match[1].upper()
    if host in {"clinicaltrials.gov", "www.clinicaltrials.gov"}:
        match = re.fullmatch(r"/(?:study|ct2/show)/(NCT\d{8})/?", path, re.IGNORECASE)
        if match:
            return "nct_id", match[1].upper()
    doi_path = path.lstrip("/")
    if host not in {"doi.org", "dx.doi.org"}:
        match = re.fullmatch(r"/doi/(?:(?:abs|abstract|epdf|full|pdf)/)?(.+)", path)
        doi_path = match[1] if match else ""
    if DOI.fullmatch(doi_path):
        return "doi", doi_path.lower()
    # Archive paths, query parameters, and fragments can identify different pages.
    return "url", urlunsplit(parts._replace(netloc=parts.netloc.lower()))


def verified_publisher_key(url, aliases, documents):
    parts = urlsplit(url)
    host = parts.hostname
    if host in {"nature.com", "www.nature.com"}:
        match = re.fullmatch(r"/articles/([a-z0-9.-]+)/?", parts.path, re.IGNORECASE)
        prefix = "10.1038/"
    elif host in {"bmj.com", "www.bmj.com"}:
        match = re.fullmatch(r"/content/(?:[^/]+/)+(bmj-\d{4}-\d+)/?", parts.path, re.IGNORECASE)
        prefix = "10.1136/"
    else:
        return None
    if match:
        key = ("doi", prefix + match[1].lower())
        if key in aliases or key in documents:
            return key
    return None


def tsv_rows(path):
    if path.is_file():
        with path.open(encoding="utf-8-sig", newline="") as handle:
            yield from csv.DictReader(handle, delimiter="\t")


def citation_rows(bucket):
    citations = {}
    for index in INDEXES:
        for row in tsv_rows(bucket / index):
            pmid = row["pmid"].strip()
            if not pmid.isdigit():
                raise ValueError(f"Invalid PMID {pmid!r} in {bucket / index}")
            pmcid = row["pmcid"].strip().upper()
            doi = row["doi"].strip()
            previous = citations.get(pmid)
            names = (index,)
            if previous:
                pmcid = previous.pmcid or pmcid
                doi = previous.doi or doi
                names = previous.index_names + (index,)
            citations[pmid] = Citation(pmid, pmcid, doi, names)
    return citations


def citation_aliases(buckets):
    citations = {}
    candidates = defaultdict(set)
    for records in buckets.values():
        for pmid, citation in records.items():
            citations.setdefault(("pmid", pmid), citation)
            for field, value in citation.identifiers().items():
                if field != "pmid":
                    candidates[(field, value.lower())].add(pmid)
    for key, matches in candidates.items():
        if len(matches) == 1:
            citations[key] = citations[("pmid", next(iter(matches)))]
    return citations


def document_headers(path):
    fields = {}
    urls = []
    if PMC_ID.fullmatch(path.stem):
        fields["pmcid"] = path.stem.upper()
    if NCT_ID.fullmatch(path.stem):
        fields["nct_id"] = path.stem.upper()
    coverage = "article text" if "pmcid" in fields else ""
    with path.open(encoding="utf-8-sig") as handle:
        for line in islice(handle, 24):
            name, separator, value = line.strip().partition(":")
            if not separator or not value.strip():
                continue
            name = name.lower()
            value = value.strip()
            if name in {"source", "source url", "source alias"} and value.startswith(("https://", "http://")):
                urls.append(value)
            elif name == "pmid" and value.isdigit():
                fields[name] = value
            elif name == "pmcid" and PMC_ID.fullmatch(value):
                fields[name] = value.upper()
            elif name == "doi" and DOI.fullmatch(value):
                fields[name] = value
            elif name == "nct id" and NCT_ID.fullmatch(value):
                fields["nct_id"] = value.upper()
            elif name == "text coverage":
                coverage = value
    return TextDocument(path, fields, tuple(urls), coverage)


def local_documents(buckets):
    documents = defaultdict(list)
    counts = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        for bucket in buckets:
            files = []
            for path in (bucket / SOURCE_DIR).rglob("*.txt"):
                info = path.stat()
                if info.st_size and stat.S_ISREG(info.st_mode):
                    files.append(path)
            counts[bucket] = len(files)
            for document in pool.map(document_headers, sorted(files)):
                keys = {(kind, value.lower()) for kind, value in document.identifiers.items()}
                keys.update((kind, value.lower() if kind != "url" else value)
                            for kind, value in map(url_key, document.urls))
                for key in keys:
                    documents[key].append(document)
    return documents, counts


def source_links(bucket):
    annotation_files = sorted(bucket.glob("*.md")) + sorted((bucket / "Observations").glob("*.md"))
    for path in annotation_files:
        if path == bucket / "README.md":
            continue
        relative = path.relative_to(bucket).as_posix()
        heading = ""
        seen = set()
        with path.open(encoding="utf-8-sig") as handle:
            for line in handle:
                match = HEADING.match(line)
                if match:
                    heading = match[1].strip()
                    seen.clear()
                for label, target in LINK.findall(line):
                    target = target.strip("<>")
                    if target not in seen:
                        seen.add(target)
                        yield relative, heading, label, target


def find_text(bucket, document_map, status_map, identifiers, source=None):
    keys = [(kind, value.lower()) for kind, value in identifiers.items()]
    if source:
        kind, value = source
        keys.insert(0, (kind, value if kind == "url" else value.lower()))
    for key in keys:
        candidates = document_map.get(key, ())
        if candidates:
            document = min(candidates, key=lambda item: (
                bucket not in item.path.parents,
                "excerpt" in item.coverage.lower(),
                item.path,
            ))
            relative = Path(os.path.relpath(document.path, bucket / SOURCE_DIR)).as_posix()
            return document, ("text_available", document.coverage, relative)
    pmcid = identifiers.get("pmcid", "").upper()
    status = status_map.get(pmcid, "text_pending")
    # Files are checked directly so a stale successful manifest cannot claim local text.
    if status == "text_available":
        status = "text_pending"
    return None, (status, "", "")


def annotated_rows(bucket, aliases, document_map, status_map):
    for annotation_file, heading, label, url in source_links(bucket):
        source = url_key(url)
        kind, key = source
        if kind == "url":
            verified = verified_publisher_key(url, aliases, document_map)
            if verified:
                kind, key = verified
        citation = aliases.get((kind, key.lower()))
        identifiers = citation.identifiers() if citation else {}
        if kind in ANNOTATED_ID_FIELDS:
            identifiers.setdefault(kind, key)
        document, text_fields = find_text(bucket, document_map, status_map, identifiers, source)
        if document:
            for field, value in document.identifiers.items():
                identifiers.setdefault(field, value)
        yield (
            "../" + annotation_file, heading, label, url,
            *(identifiers.get(field, "") for field in ANNOTATED_ID_FIELDS), *text_fields,
        )


def literature_rows(bucket, citations, document_map, status_map):
    for citation in citations.values():
        _, text_fields = find_text(bucket, document_map, status_map, citation.identifiers())
        yield (
            citation.pmid, citation.pmcid, citation.doi,
            "; ".join("../" + name for name in citation.index_names), *text_fields,
        )


def registered_rows(bucket, document_map):
    index = "Study-Registry.tsv"
    for row in tsv_rows(bucket / index):
        nct_id = row["nct_id"]
        _, text_fields = find_text(bucket, document_map, {}, {"nct_id": nct_id})
        yield nct_id, "../" + index, *text_fields


def write_catalog(path, columns, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tsv.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(columns)
        writer.writerows(rows)
    temporary.replace(path)


def build(root):
    buckets = {
        path: citation_rows(path)
        for path in sorted(root.iterdir())
        if path.is_dir() and BUCKET.fullmatch(path.name)
    }
    aliases = citation_aliases(buckets)
    document_map, text_counts = local_documents(buckets)
    status_map = {
        row["pmcid"].upper(): row["retrieval_status"]
        for row in tsv_rows(root / "PMC-Text-Retrieval.tsv")
        if row["retrieval_status"] in {"text_available", "no_eligible_version", "download_error"}
    }
    coverage = []
    for bucket, citations in buckets.items():
        output = bucket / SOURCE_DIR
        articles = list(literature_rows(bucket, citations, document_map, status_map))
        annotated = list(annotated_rows(bucket, aliases, document_map, status_map))
        registered = list(registered_rows(bucket, document_map))
        write_catalog(output / "Literature-Catalog.tsv", (*ID_FIELDS, "citation_index", *STATUS_FIELDS), articles)
        write_catalog(output / "Annotated-Sources.tsv", (
            "annotation_file", "annotation_heading", "link_label", "source_url", *ANNOTATED_ID_FIELDS, *STATUS_FIELDS,
        ), annotated)
        write_catalog(output / "Registered-Studies.tsv", ("nct_id", "registry_index", *STATUS_FIELDS), registered)
        coverage.append((
            bucket.name,
            len(articles), sum(row[-3] == "text_available" for row in articles),
            len(annotated), sum(row[-3] == "text_available" for row in annotated),
            text_counts[bucket],
            len(registered), sum(row[-3] == "text_available" for row in registered),
        ))
    write_catalog(root / "Source-Text-Coverage.tsv", (
        "bucket", "literature_records", "literature_with_text", "annotated_links", "annotated_links_with_text",
        "local_text_files", "registered_studies", "registered_studies_with_text",
    ), coverage)
    print(f"Cataloged {sum(row[1] for row in coverage):,} citations and "
          f"{sum(row[3] for row in coverage):,} annotated links and "
          f"{sum(row[6] for row in coverage):,} registrations across {len(coverage)} periods.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="Research folder to catalog")
    args = parser.parse_args()
    build(args.root.resolve())


if __name__ == "__main__":
    main()
