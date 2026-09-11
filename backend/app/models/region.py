import uuid

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ClimateZone(Base):
    __tablename__ = "climate_zones"

    climate_zone_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)


class HddValue(Base):
    __tablename__ = "hdd_values"
    __table_args__ = (CheckConstraint("hdd_value_k_day > 0", name="ck_hdd_values_positive"),)

    hdd_lookup_key: Mapped[str] = mapped_column(String, primary_key=True)
    hdd_value_k_day: Mapped[float] = mapped_column(Numeric, nullable=False)
    reference_document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reference_documents.reference_document_id"), nullable=False
    )


class SupportedRegion(Base):
    __tablename__ = "supported_regions"

    region_id: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    is_supported: Mapped[bool] = mapped_column(Boolean, nullable=False)
    hdd_lookup_key: Mapped[str] = mapped_column(String, ForeignKey("hdd_values.hdd_lookup_key"), nullable=False)
    climate_zone_key: Mapped[str] = mapped_column(
        String, ForeignKey("climate_zones.climate_zone_key"), nullable=False
    )
    region_data_version: Mapped[str] = mapped_column(String, nullable=False)
