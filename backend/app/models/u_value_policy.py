import uuid

from sqlalchemy import CheckConstraint, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class CurrentWindowUValuePolicy(Base):
    __tablename__ = "current_window_u_value_policies"
    __table_args__ = (
        UniqueConstraint(
            "window_type_key", "low_e_key", "policy_version", name="uq_current_window_u_value_policies"
        ),
        CheckConstraint("u_value_w_m2k > 0", name="ck_current_window_u_value_policies_positive"),
    )

    current_window_u_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    window_type_key: Mapped[str] = mapped_column(String, nullable=False)
    low_e_key: Mapped[str] = mapped_column(String, nullable=False)
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class CurrentWallUValuePolicy(Base):
    __tablename__ = "current_wall_u_value_policies"
    __table_args__ = (
        UniqueConstraint(
            "construction_year_range_key",
            "insulation_status_key",
            "policy_version",
            name="uq_current_wall_u_value_policies",
        ),
        CheckConstraint("u_value_w_m2k > 0", name="ck_current_wall_u_value_policies_positive"),
    )

    current_wall_u_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    construction_year_range_key: Mapped[str] = mapped_column(
        String, ForeignKey("construction_year_ranges.construction_year_range_key"), nullable=False
    )
    insulation_status_key: Mapped[str] = mapped_column(
        String, ForeignKey("insulation_statuses.insulation_status_key"), nullable=False
    )
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    policy_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class TargetUValuePolicy(Base):
    __tablename__ = "target_u_value_policies"
    __table_args__ = (
        CheckConstraint("u_value_w_m2k > 0", name="ck_target_u_value_policies_positive"),
        CheckConstraint(
            "(climate_zone_key IS NOT NULL) <> (region_id IS NOT NULL)",
            name="ck_target_u_value_policies_scope_xor",
        ),
    )

    target_u_policy_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    building_group_key: Mapped[str] = mapped_column(
        String, ForeignKey("target_u_value_building_groups.building_group_key"), nullable=False
    )
    component_key: Mapped[str] = mapped_column(String, ForeignKey("building_components.component_key"), nullable=False)
    climate_zone_key: Mapped[str | None] = mapped_column(
        String, ForeignKey("climate_zones.climate_zone_key"), nullable=True
    )
    region_id: Mapped[str | None] = mapped_column(String, ForeignKey("supported_regions.region_id"), nullable=True)
    appendix_identifier: Mapped[str] = mapped_column(String, nullable=False)
    condition_description: Mapped[str] = mapped_column(Text, nullable=False)
    u_value_w_m2k: Mapped[float] = mapped_column(Numeric, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )
