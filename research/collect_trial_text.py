"""Save selected public ClinicalTrials.gov study record fields as plain text."""

import argparse
import re
from datetime import datetime, timezone
from pathlib import Path

from build_source_catalog import BUCKET, NCT_ID, ROOT, SOURCE_DIR, tsv_rows
from collect_indexes import FIRST_YEAR, TRIAL_API, TRIAL_QUERY, fetch_json


TERMS = "https://clinicaltrials.gov/about-site/terms-conditions"
FIELDS = ",".join((
    "IdentificationModule", "StatusModule", "LeadSponsor", "DescriptionModule",
    "ConditionsModule", "DesignModule", "ArmsInterventionsModule", "OutcomesModule",
    "EligibilityModule", "HasResults", "ParticipantFlowModule", "OutcomeMeasuresModule",
    "EventGroup", "LimitationsAndCaveats",
))
EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[a-z]{2,}\b", re.IGNORECASE)
PHONE = re.compile(r"(?<!\w)(?:\+1[ .-])?(?:\(\d{3}\) ?|\d{3}[ .-])\d{3}[ .-]\d{4}(?!\w)")
CAMEL_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")


def indexed_studies(root):
    indexed = {}
    for bucket in sorted(root.iterdir()):
        if not bucket.is_dir() or not BUCKET.fullmatch(bucket.name):
            continue
        for row in tsv_rows(bucket / "Study-Registry.tsv"):
            nct_id = row["nct_id"]
            if not NCT_ID.fullmatch(nct_id) or nct_id in indexed:
                raise ValueError(f"Invalid or duplicate NCT ID {nct_id!r} in {bucket}")
            indexed[nct_id] = (bucket, row["first_posted"])
    if not indexed:
        raise ValueError(f"No indexed ClinicalTrials.gov studies in {root}")
    return indexed


def strip_contacts(text):
    text = EMAIL.sub("[contact email omitted]", text)
    return PHONE.sub("[contact phone omitted]", text)


def field_label(name):
    return CAMEL_BOUNDARY.sub(" ", name).capitalize()


def plain_value(value):
    if isinstance(value, bool):
        return "Yes" if value else "No"
    return strip_contacts(str(value)).strip()


def text_lines(value, depth=0):
    indent = "  " * depth
    if isinstance(value, dict):
        for name, item in value.items():
            label = field_label(name)
            if isinstance(item, (dict, list)):
                if item:
                    yield f"{indent}{label}"
                    yield from text_lines(item, depth + 1)
            elif item is not None:
                rendered = plain_value(item)
                if "\n" in rendered:
                    yield f"{indent}{label}"
                    yield from (f"{indent}  {line}".rstrip() for line in rendered.splitlines())
                elif rendered:
                    yield f"{indent}{label}: {rendered}"
    elif isinstance(value, list):
        for item in value:
            if isinstance(item, dict):
                yield f"{indent}-"
                yield from text_lines(item, depth + 1)
            else:
                yield f"{indent}- {plain_value(item)}"
    elif value:
        yield from (f"{indent}{line}".rstrip() for line in plain_value(value).splitlines())


def append_section(lines, title, data):
    if data:
        lines.extend(("", title, ""))
        lines.extend(text_lines(data))


def study_text(study, processed, retrieved):
    protocol = study["protocolSection"]
    identity = protocol["identificationModule"]
    dates = protocol.get("statusModule", {})
    nct_id = identity["nctId"]
    title = identity.get("briefTitle", nct_id)
    posted_results = "Yes" if study.get("hasResults") else "No"
    lines = [
        strip_contacts(title),
        "",
        f"Source: https://clinicaltrials.gov/study/{nct_id}",
        "Source credit: ClinicalTrials.gov, U.S. National Library of Medicine, U.S. Government database",
        f"NCT ID: {nct_id}",
        f"First posted: {dates.get('studyFirstPostDateStruct', {}).get('date', 'Unknown')}",
        f"Registry last update posted: {dates.get('lastUpdatePostDateStruct', {}).get('date', 'Unknown')}",
        f"Data processed by ClinicalTrials.gov: {processed}",
        f"Retrieved (UTC): {retrieved}",
        f"Posted summary results: {posted_results}",
        "Text coverage: selected registry record fields",
        f"Data terms: {TERMS}",
        "Modifications: selected public registration fields and selected summary results converted from JSON to text.",
        "Formatting and field labels were changed. Contact details, attachments, external publications, locations,",
        "baseline tables, and individual adverse-event tables are omitted. Contact patterns in free text are redacted.",
    ]
    official_title = identity.get("officialTitle", "")
    if official_title and official_title != title:
        append_section(lines, "OFFICIAL TITLE", official_title)
    sponsor = protocol.get("sponsorCollaboratorsModule", {}).get("leadSponsor", {}).get("name")
    append_section(lines, "LEAD SPONSOR", sponsor)
    append_section(lines, "STUDY STATUS", {
        "overallStatus": dates.get("overallStatus"),
        "whyStopped": dates.get("whyStopped"),
        "startDate": dates.get("startDateStruct"),
        "primaryCompletionDate": dates.get("primaryCompletionDateStruct"),
        "completionDate": dates.get("completionDateStruct"),
    })
    descriptions = protocol.get("descriptionModule", {})
    append_section(lines, "BRIEF SUMMARY", descriptions.get("briefSummary"))
    append_section(lines, "DETAILED DESCRIPTION", descriptions.get("detailedDescription"))
    append_section(lines, "CONDITIONS", protocol.get("conditionsModule", {}).get("conditions"))
    for title, module in (
        ("STUDY DESIGN", "designModule"),
        ("STUDY GROUPS AND INTERVENTIONS", "armsInterventionsModule"),
        ("REGISTERED OUTCOME MEASURES", "outcomesModule"),
        ("ELIGIBILITY", "eligibilityModule"),
    ):
        append_section(lines, title, protocol.get(module))
    results = study.get("resultsSection", {})
    if results:
        lines.extend(("", "POSTED SUMMARY RESULTS"))
        append_section(lines, "PARTICIPANT FLOW", results.get("participantFlowModule"))
        append_section(lines, "OUTCOME MEASURE RESULTS", results.get("outcomeMeasuresModule"))
        append_section(lines, "ADVERSE EVENT GROUP TOTALS", results.get("adverseEventsModule", {}).get("eventGroups"))
        append_section(lines, "LIMITATIONS AND CAVEATS", results.get("moreInfoModule", {}).get("limitationsAndCaveats"))
    return "\n".join(lines) + "\n"


def search_pages(parameters):
    parameters = {"fields": FIELDS, "pageSize": 400, "markupFormat": "legacy", **parameters}
    tokens = set()
    while True:
        page = fetch_json(TRIAL_API, parameters)
        yield from page["studies"]
        token = page.get("nextPageToken")
        if not token:
            break
        if token in tokens:
            raise ValueError("ClinicalTrials.gov repeated a pagination token")
        tokens.add(token)
        parameters["pageToken"] = token


def collect(root):
    pending = indexed_studies(root)
    count = len(pending)
    cutoff = max(posted for _, posted in pending.values())
    version_api = TRIAL_API.rsplit("/", 1)[0] + "/version"
    processed = fetch_json(version_api, {})["dataTimestamp"]
    retrieved = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with_results = 0

    def write_study(study):
        nonlocal with_results
        nct_id = study["protocolSection"]["identificationModule"]["nctId"]
        match = pending.get(nct_id)
        if match is None:
            return
        bucket, indexed_date = match
        status = study["protocolSection"]["statusModule"]
        if status["studyFirstPostDateStruct"]["date"] != indexed_date:
            raise ValueError(f"First-posted date changed for {nct_id}")
        directory = bucket / SOURCE_DIR / "Trials"
        directory.mkdir(parents=True, exist_ok=True)
        destination = directory / f"{nct_id}.txt"
        temporary = destination.with_suffix(".txt.tmp")
        with temporary.open("w", encoding="utf-8", newline="\n") as handle:
            handle.write(study_text(study, processed, retrieved))
        temporary.replace(destination)
        pending.pop(nct_id)
        with_results += bool(study.get("hasResults"))

    for study in search_pages({
        "query.cond": TRIAL_QUERY,
        "filter.advanced": f"AREA[StudyFirstPostDate]RANGE[{FIRST_YEAR}-01-01,{cutoff}]",
    }):
        write_study(study)

    # Search indexing can change after the local citation snapshot.
    remaining = sorted(pending)
    for offset in range(0, len(remaining), 100):
        for study in search_pages({"filter.ids": ",".join(remaining[offset:offset + 100])}):
            write_study(study)
    if pending:
        raise ValueError(f"{len(pending)} indexed trials were unavailable: {', '.join(sorted(pending))}")
    if fetch_json(version_api, {})["dataTimestamp"] != processed:
        raise ValueError("ClinicalTrials.gov refreshed during download. Rerun for a consistent processing date.")
    print(f"Saved {count:,} study records, including {with_results:,} with posted summary results.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="Research folder with existing study indexes")
    args = parser.parse_args()
    collect(args.root.resolve())


if __name__ == "__main__":
    main()
