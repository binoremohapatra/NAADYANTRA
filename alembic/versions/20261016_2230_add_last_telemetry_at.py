"""Add last_telemetry_at to devices

Revision ID: a82d3e5f1b9c
Revises: 7e2db777e8ac
Create Date: 2026-10-16 22:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a82d3e5f1b9c'
down_revision = '7e2db777e8ac'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add last_telemetry_at column to devices table safely
    op.add_column('devices', sa.Column('last_telemetry_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('devices', 'last_telemetry_at')
