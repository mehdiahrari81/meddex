import csv
import hashlib
import io
import json
import re
from typing import Any, ClassVar


class DrapParser:
    HEADER_ALIASES: ClassVar[dict[str, list[str]]] = {
        "registration_id": [
            "registration number",
            "reg no",
            "registration no.",
            "registration no",
            "registration_id",
            "id",
        ],
        "brand_name": ["brand name", "product name", "brand", "product"],
        "generic_name": ["generic name", "generic", "active ingredients"],
        "composition": ["composition", "ingredients", "formula"],
        "dosage_form": ["dosage form", "form", "presentation"],
        "manufacturer": ["manufacturer", "company", "market authorization holder", "mah"],
    }

    @classmethod
    def parse_csv(cls, file_content: str | bytes) -> list[dict[str, Any]]:
        try:
            return cls._parse_csv(file_content)
        except (UnicodeDecodeError, csv.Error) as error:
            raise ValueError("invalid_utf8_csv") from error

    @classmethod
    def _parse_csv(cls, file_content: str | bytes) -> list[dict[str, Any]]:
        content_str = (
            file_content.decode("utf-8-sig") if isinstance(file_content, bytes) else file_content
        )
        reader = csv.reader(io.StringIO(content_str), strict=True)

        headers_row = next(reader, None)
        if not headers_row:
            raise ValueError("empty_file")

        header_map = cls._map_headers(headers_row)

        required = ["registration_id", "brand_name"]
        for req in required:
            if req not in header_map:
                raise ValueError(f"missing_required_column_{req}")

        records: list[dict[str, Any]] = []
        for row in reader:
            if not any(row):
                continue
            if len(row) != len(headers_row):
                raise ValueError(f"column_count_mismatch_row_{reader.line_num}")
            if len(records) >= 10_000:
                raise ValueError("record_limit_exceeded")

            record_raw = {
                key: (row[idx].strip() if idx < len(row) else "") for key, idx in header_map.items()
            }

            if not record_raw.get("registration_id"):
                raise ValueError(f"missing_registration_id_row_{reader.line_num}")

            record = cls._normalize_record(record_raw)
            records.append(record)

        if not records:
            raise ValueError("no_product_records")
        return cls._deduplicate(records)

    @classmethod
    def _map_headers(cls, headers: list[str]) -> dict[str, int]:
        mapping = {}
        for idx, header in enumerate(headers):
            normalized = header.strip().lower()
            for key, aliases in cls.HEADER_ALIASES.items():
                if (normalized in aliases or normalized == key) and key not in mapping:
                    mapping[key] = idx
                    break
        return mapping

    @classmethod
    def _normalize_record(cls, raw: dict[str, str]) -> dict[str, Any]:
        brand_name = raw.get("brand_name", "")
        composition_raw = raw.get("composition", "")

        # Derive an ingredient name only from supplied composition, never a brand.
        ingredients = cls.parse_composition(composition_raw or raw.get("generic_name", ""))
        generic_name = raw.get("generic_name") or " + ".join(
            str(ingredient["name"]) for ingredient in ingredients
        )

        # Fingerprint
        fingerprint_data = json.dumps(raw, sort_keys=True, separators=(",", ":"))
        fingerprint = hashlib.sha256(fingerprint_data.encode()).hexdigest()

        return {
            "registration_id": raw.get("registration_id"),
            "brand_name": brand_name,
            "generic_name": generic_name,
            "dosage_form": raw.get("dosage_form"),
            "manufacturer": raw.get("manufacturer"),
            "raw_composition": composition_raw,
            "ingredients": ingredients,
            "fingerprint": fingerprint,
        }

    @classmethod
    def parse_composition(cls, raw: str) -> list[dict[str, str | None]]:
        # Handle "Amoxicillin 500mg + Clavulanic Acid 125mg"
        parts = re.split(r"\s*\+\s*|\s+and\s+", raw, flags=re.IGNORECASE)
        ingredients = []
        for part in parts:
            part = part.strip()
            if not part:
                continue

            # e.g. "Paracetamol 120mg/5ml" or "Ibuprofen 400 mg"
            # match = (Name) (Value) (Unit)[/(DenomValue)(DenomUnit)]
            match = re.search(
                r"^(.*?)\s+(\d+(?:\.\d+)?)\s*(mg|mcg|μg|g|ml|%|iu|units?)"
                r"(?:\s*/\s*(\d+(?:\.\d+)?)?\s*(ml|g))?$",
                part,
                flags=re.IGNORECASE,
            )
            if match:
                denom = f"/{match.group(4) or ''}{match.group(5)}" if match.group(5) else ""
                ingredients.append(
                    {
                        "name": match.group(1).strip(),
                        "value": match.group(2).strip(),
                        "unit": (match.group(3).strip() + denom).strip(),
                    }
                )
            else:
                ingredients.append({"name": part, "value": None, "unit": None})
        return ingredients

    @classmethod
    def _deduplicate(cls, records: list[dict[str, Any]]) -> list[dict[str, Any]]:
        unique = {}
        for r in records:
            # Prefer first occurrence, but log duplicates if needed in future
            if r["fingerprint"] not in unique:
                unique[r["fingerprint"]] = r
        return list(unique.values())
