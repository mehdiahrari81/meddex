"""add_drap_indexes

Revision ID: c9ce88999c02
Revises: 98e5f4666626
Create Date: 2026-08-19 19:50:32.156287
"""

from collections.abc import Sequence

from alembic import op

revision: str = "c9ce88999c02"
down_revision: str | None = "98e5f4666626"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_medication_identity_fuzzy_name "
        "ON medication_identities USING gin (normalized_name gin_trgm_ops);"
    )


def downgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("DROP INDEX IF EXISTS ix_medication_identity_fuzzy_name;")
    # pg_trgm can be shared with other schemas. Keep the extension installed.
