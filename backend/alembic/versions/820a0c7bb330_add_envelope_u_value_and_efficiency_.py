"""add envelope (ceiling/floor/door) u-value policies and energy efficiency bands

Revision ID: 820a0c7bb330
Revises: 878a1a776a54
Create Date: 2026-09-12 03:10:00.000000

calc-v2 (docs/result-screen-v9-design.md) 확장용 스키마. 기존
current_wall/window_u_value_policies, target_u_value_policies는 그대로 두고
천장/바닥/문 3개 테이블과 에너지 효율 레벨 밴드 테이블만 추가한다.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '820a0c7bb330'
down_revision: Union[str, None] = '878a1a776a54'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'current_ceiling_u_value_policies',
        sa.Column('current_ceiling_u_policy_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('construction_year_range_key', sa.String(), nullable=False),
        sa.Column('u_value_w_m2k', sa.Numeric(), nullable=False),
        sa.Column('policy_version', sa.String(), nullable=False),
        sa.Column('reference_document_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.CheckConstraint('u_value_w_m2k > 0', name='ck_current_ceiling_u_value_policies_positive'),
        sa.ForeignKeyConstraint(['construction_year_range_key'], ['construction_year_ranges.construction_year_range_key']),
        sa.ForeignKeyConstraint(['reference_document_id'], ['reference_documents.reference_document_id']),
        sa.PrimaryKeyConstraint('current_ceiling_u_policy_id'),
        sa.UniqueConstraint('construction_year_range_key', 'policy_version', name='uq_current_ceiling_u_value_policies'),
    )
    op.create_table(
        'current_floor_u_value_policies',
        sa.Column('current_floor_u_policy_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('construction_year_range_key', sa.String(), nullable=False),
        sa.Column('u_value_w_m2k', sa.Numeric(), nullable=False),
        sa.Column('policy_version', sa.String(), nullable=False),
        sa.Column('reference_document_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.CheckConstraint('u_value_w_m2k > 0', name='ck_current_floor_u_value_policies_positive'),
        sa.ForeignKeyConstraint(['construction_year_range_key'], ['construction_year_ranges.construction_year_range_key']),
        sa.ForeignKeyConstraint(['reference_document_id'], ['reference_documents.reference_document_id']),
        sa.PrimaryKeyConstraint('current_floor_u_policy_id'),
        sa.UniqueConstraint('construction_year_range_key', 'policy_version', name='uq_current_floor_u_value_policies'),
    )
    op.create_table(
        'current_door_u_value_policies',
        sa.Column('current_door_u_policy_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('construction_year_range_key', sa.String(), nullable=False),
        sa.Column('u_value_w_m2k', sa.Numeric(), nullable=False),
        sa.Column('policy_version', sa.String(), nullable=False),
        sa.Column('reference_document_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.CheckConstraint('u_value_w_m2k > 0', name='ck_current_door_u_value_policies_positive'),
        sa.ForeignKeyConstraint(['construction_year_range_key'], ['construction_year_ranges.construction_year_range_key']),
        sa.ForeignKeyConstraint(['reference_document_id'], ['reference_documents.reference_document_id']),
        sa.PrimaryKeyConstraint('current_door_u_policy_id'),
        sa.UniqueConstraint('construction_year_range_key', 'policy_version', name='uq_current_door_u_value_policies'),
    )
    op.create_table(
        'energy_efficiency_bands',
        sa.Column('energy_efficiency_band_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('band_level', sa.Integer(), nullable=False),
        sa.Column('label', sa.String(), nullable=False),
        sa.Column('min_kwh_per_m2', sa.Numeric(), nullable=True),
        sa.Column('max_kwh_per_m2', sa.Numeric(), nullable=True),
        sa.Column('policy_version', sa.String(), nullable=False),
        sa.CheckConstraint('band_level BETWEEN 1 AND 5', name='ck_energy_efficiency_bands_level_range'),
        sa.PrimaryKeyConstraint('energy_efficiency_band_id'),
        sa.UniqueConstraint('band_level', 'policy_version', name='uq_energy_efficiency_bands'),
    )


def downgrade() -> None:
    op.drop_table('energy_efficiency_bands')
    op.drop_table('current_door_u_value_policies')
    op.drop_table('current_floor_u_value_policies')
    op.drop_table('current_ceiling_u_value_policies')
