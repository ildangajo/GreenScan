"""천장/바닥/문 현재 U값 정책 (calc-v2, docs/result-screen-v9-design.md 1~2절).

CurrentWallUValuePolicy와 달리 insulation_status_key로 나누지 않는다 —
사용자가 천장/바닥 단열 상태를 육안으로 판별하기 어려워서(벽체와 달리
사진/현장에서 확인하기 힘든 부위) 연식만으로 대표값을 준다. 창호처럼
2종류(유형×Low-E)로 나눌 입력도 없다.

⚠️ 시드값 출처 주의(seed_envelope_u_values.py 참고): 벽체/창호처럼
PHIKO·국토부 고시 원문을 대조 확인한 게 아니라, 같은 고시(에너지절약
설계기준 별표1)가 지붕/바닥/문도 같은 표에서 규정한다는 공학적 통념에
기반한 잠정 추정치다. 실제 원문 대조 전까지 policy_version에
"-unverified" 접미사를 붙여 구분한다.
"""

import uuid

from sqlalchemy import CheckConstraint, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class CurrentCeilingUValuePolicy(Base):
    __tablename__ = "current_ceiling_u_value_policies"
    __table_args__ = (
        UniqueConstraint("construction_year_range_key", "policy_version", name="uq_current_ceiling_u_value_policies"),
        CheckConstraint("u_value_w_m2k > 0", name="ck_current_ceiling_u_value_policies_positive"),
    )

    current_ceiling_u_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    construction_year_range_key: Mapped[str] = mapped_column(
        String, ForeignKey("construction_year_ranges.construction_year_range_key"), nullable=False
    )
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class CurrentFloorUValuePolicy(Base):
    __tablename__ = "current_floor_u_value_policies"
    __table_args__ = (
        UniqueConstraint("construction_year_range_key", "policy_version", name="uq_current_floor_u_value_policies"),
        CheckConstraint("u_value_w_m2k > 0", name="ck_current_floor_u_value_policies_positive"),
    )

    current_floor_u_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    construction_year_range_key: Mapped[str] = mapped_column(
        String, ForeignKey("construction_year_ranges.construction_year_range_key"), nullable=False
    )
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class CurrentDoorUValuePolicy(Base):
    __tablename__ = "current_door_u_value_policies"
    __table_args__ = (
        UniqueConstraint("construction_year_range_key", "policy_version", name="uq_current_door_u_value_policies"),
        CheckConstraint("u_value_w_m2k > 0", name="ck_current_door_u_value_policies_positive"),
    )

    current_door_u_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    construction_year_range_key: Mapped[str] = mapped_column(
        String, ForeignKey("construction_year_ranges.construction_year_range_key"), nullable=False
    )
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class EnergyEfficiencyBand(Base):
    """docs/result-screen-v9-design.md 1절: 면적당 연간 열손실(kWh/m²)을
    LV.1(긴급)~LV.5(매우 좋음) 5단계로 나누는 밴드. min_kwh_per_m2가 NULL이면
    하한 없음(가장 좋은 밴드), max_kwh_per_m2가 NULL이면 상한 없음(가장 나쁜 밴드).
    """

    __tablename__ = "energy_efficiency_bands"
    __table_args__ = (
        UniqueConstraint("band_level", "policy_version", name="uq_energy_efficiency_bands"),
        CheckConstraint("band_level BETWEEN 1 AND 5", name="ck_energy_efficiency_bands_level_range"),
    )

    energy_efficiency_band_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    band_level: Mapped[int] = mapped_column(nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)
    min_kwh_per_m2: Mapped[float | None] = mapped_column(Numeric, nullable=True)
    max_kwh_per_m2: Mapped[float | None] = mapped_column(Numeric, nullable=True)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
