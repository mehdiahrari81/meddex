import re
import unicodedata
from dataclasses import dataclass
from functools import lru_cache

from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.models import MedicalAbbreviation, MedicalTerm, TermAlias


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(char for char in decomposed if not unicodedata.combining(char))
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9\s-]", " ", without_marks)).strip()


def edit_distance(left: str, right: str) -> int:
    if len(left) > len(right):
        left, right = right, left
    previous = list(range(len(left) + 1))
    for right_index, right_char in enumerate(right, start=1):
        current = [right_index]
        for left_index, left_char in enumerate(left, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[left_index] + 1,
                    previous[left_index - 1] + (left_char != right_char),
                )
            )
        previous = current
    return previous[-1]


@dataclass(frozen=True)
class RankedTerm:
    term: MedicalTerm
    match_type: str
    matched_text: str
    relevance: float
    is_suggestion: bool


class TerminologySearchService:
    def __init__(self, db: Session, *, published_statuses: tuple[str, ...]) -> None:
        self.db = db
        self.published_statuses = published_statuses

    def search(
        self,
        query: str,
        *,
        category: str | None,
        language: str,
    ) -> tuple[list[RankedTerm], bool]:
        normalized = normalize(query)
        abbreviation_rows = self.db.scalars(
            select(MedicalAbbreviation)
            .join(MedicalTerm, MedicalTerm.id == MedicalAbbreviation.term_id)
            .where(
                MedicalAbbreviation.normalized_abbreviation == normalized,
                MedicalTerm.deprecated.is_(False),
                MedicalTerm.review_status.in_(self.published_statuses),
            )
        ).all()
        match_priority = case(
            (MedicalTerm.normalized_term == normalized, 0),
            (TermAlias.normalized_alias == normalized, 1),
            (MedicalTerm.normalized_term.like(f"{normalized}%"), 2),
            (TermAlias.normalized_alias.like(f"{normalized}%"), 3),
            else_=4,
        )
        candidate_statement = (
            select(
                MedicalTerm.id.label("term_id"),
                func.min(match_priority).label("match_priority"),
                func.abs(func.length(MedicalTerm.normalized_term) - len(normalized)).label(
                    "length_distance"
                ),
            )
            .outerjoin(TermAlias, TermAlias.term_id == MedicalTerm.id)
            .where(
                MedicalTerm.language == language,
                MedicalTerm.deprecated.is_(False),
                MedicalTerm.review_status.in_(self.published_statuses),
                or_(
                    MedicalTerm.normalized_term == normalized,
                    MedicalTerm.normalized_term.like(f"{normalized}%"),
                    MedicalTerm.normalized_term.like(f"%{normalized}%"),
                    TermAlias.normalized_alias == normalized,
                    TermAlias.normalized_alias.like(f"{normalized}%"),
                    MedicalTerm.normalized_term.like(f"{normalized[:1]}%"),
                ),
            )
            .group_by(MedicalTerm.id)
            .order_by("match_priority", "length_distance", MedicalTerm.normalized_term)
            .limit(250)
        )
        if category:
            candidate_statement = candidate_statement.where(MedicalTerm.category_id == category)
        candidates = candidate_statement.subquery()
        statement = (
            select(MedicalTerm)
            .join(candidates, candidates.c.term_id == MedicalTerm.id)
            .order_by(
                candidates.c.match_priority,
                candidates.c.length_distance,
                MedicalTerm.normalized_term,
            )
        )
        terms = self.db.scalars(statement).all()
        term_ids = [term.id for term in terms]
        aliases = (
            self.db.scalars(select(TermAlias).where(TermAlias.term_id.in_(term_ids))).all()
            if term_ids
            else []
        )
        by_term: dict[str, list[TermAlias]] = {}
        for alias in aliases:
            by_term.setdefault(alias.term_id, []).append(alias)
        ranks: list[RankedTerm] = []
        priorities = {
            "exact": 1000,
            "synonym": 900,
            "layEquivalent": 850,
            "abbreviation": 800,
            "partial": 700,
            "fuzzy": 500,
        }
        type_map = {
            "synonym": "synonym",
            "lay": "layEquivalent",
            "abbreviation": "abbreviation",
            "alternative": "partial",
        }
        for term in terms:
            values: list[tuple[str, str]] = [(term.normalized_term, "exact")]
            values.extend(
                (alias.normalized_alias, type_map[alias.alias_type])
                for alias in by_term.get(term.id, [])
            )
            best: RankedTerm | None = None
            for text, declared_type in values:
                match_type: str | None = None
                bonus = 0.0
                if text == normalized:
                    match_type = declared_type
                    bonus = 40
                elif text.startswith(normalized) or f" {normalized}" in text:
                    match_type = "partial"
                    bonus = 20
                else:
                    distance = edit_distance(normalized, text)
                    maximum = 1 if len(normalized) <= 5 else 2
                    similarity = 1 - (distance / max(len(normalized), len(text), 1))
                    if distance <= maximum and similarity >= 0.72:
                        match_type = "fuzzy"
                        bonus = similarity * 100
                if match_type is None:
                    continue
                candidate = RankedTerm(
                    term=term,
                    match_type=match_type,
                    matched_text=text,
                    relevance=priorities[match_type] + bonus,
                    is_suggestion=match_type == "fuzzy",
                )
                if best is None or candidate.relevance > best.relevance:
                    best = candidate
            if best is not None:
                ranks.append(best)
        ranks.sort(key=lambda value: (-value.relevance, value.term.canonical_term))
        ambiguous = len(abbreviation_rows) > 1 or any(row.ambiguous for row in abbreviation_rows)
        if ambiguous:
            ranks = [item for item in ranks if item.match_type == "abbreviation"]
        return ranks, ambiguous


@lru_cache(maxsize=2048)
def safe_page_offset(page: int, page_size: int) -> int:
    return (page - 1) * page_size
