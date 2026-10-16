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
    # Safely and idempotently add last_telemetry_at to devices table
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c['name'] for c in inspector.get_columns('devices')]
    if 'last_telemetry_at' not in columns:
        op.add_column('devices', sa.Column('last_telemetry_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c['name'] for c in inspector.get_columns('devices')]
    if 'last_telemetry_at' in columns:
        op.drop_column('devices', 'last_telemetry_at')
