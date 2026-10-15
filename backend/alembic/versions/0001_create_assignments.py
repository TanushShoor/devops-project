"""Create assignments table.

Revision ID: 0001_create_assignments
Revises:
Create Date: 2026-10-15
"""
from alembic import op
import sqlalchemy as sa

revision = "0001_create_assignments"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "assignments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("course", sa.String(length=120), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("priority", sa.String(length=20), nullable=False, server_default="MEDIUM"),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="TODO"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade():
    op.drop_table("assignments")
