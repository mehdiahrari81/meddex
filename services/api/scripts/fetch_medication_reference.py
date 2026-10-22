"""Fetch exact ingredient and clinical drug names from NLM; never synthesize medical facts."""

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

import httpx

QUERIES = [
    "acetaminophen",
    "ibuprofen",
    "amoxicillin",
    "metformin",
    "omeprazole",
    "cetirizine",
    "loratadine",
    "atorvastatin",
    "amlodipine",
    "losartan",
    "levothyroxine",
    "azithromycin",
    "doxycycline",
    "ferrous sulfate",
    "folic acid",
    "albuterol",
    "aspirin",
    "naproxen",
    "pantoprazole",
    "hydrochlorothiazide",
]
BASE = "https://rxnav.nlm.nih.gov/REST"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    records = {}
    with httpx.Client(
        timeout=30, headers={"User-Agent": "MediExplain-reference-import/1.0"}
    ) as client:
        version_response = client.get(f"{BASE}/version.json")
        version_response.raise_for_status()
        version = version_response.json()["version"]
        for query in QUERIES:
            response = client.get(f"{BASE}/drugs.json", params={"name": query})
            response.raise_for_status()
            groups = response.json().get("drugGroup", {}).get("conceptGroup", []) or []
            exact = client.get(f"{BASE}/rxcui.json", params={"name": query, "search": "0"})
            exact.raise_for_status()
            concepts = [
                {"rxcui": value}
                for value in (exact.json().get("idGroup", {}).get("rxnormId") or [])
            ]

            for group in groups:
                if group.get("tty") in {"IN", "SCD"}:
                    concepts.extend((group.get("conceptProperties") or [])[:3])
            for item in concepts:
                url = f"{BASE}/rxcui/{item['rxcui']}/properties.json"
                verified = client.get(url)
                verified.raise_for_status()
                properties = verified.json().get("properties")
                if not properties or properties.get("suppress") != "N":
                    continue
                if properties["tty"] not in {"IN", "SCD"}:
                    continue
                records[properties["rxcui"]] = {
                    key: properties[key] for key in ("rxcui", "name", "tty")
                } | {"source_url": url}
            print(f"Verified {query}: {len(records)} total records", flush=True)
    document = {
        "source": "NLM RxNorm",
        "version": version,
        "retrieved_at": datetime.now(UTC).isoformat(),
        "records": sorted(records.values(), key=lambda row: row["name"]),
    }
    if not records:
        raise RuntimeError("No records verified; existing snapshot preserved")
    args.output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
