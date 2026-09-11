from sqlalchemy import ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class TargetUValueBuildingGroup(Base):
    __tablename__ = "target_u_value_building_groups"

    building_group_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)


class BuildingTypeTargetGroupMapping(Base):
    __tablename__ = "building_type_target_group_mappings"

    building_type_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    building_group_key: Mapped[str] = mapped_column(
        String, ForeignKey("target_u_value_building_groups.building_group_key"), nullable=False
    )


class BuildingComponent(Base):
    __tablename__ = "building_components"

    component_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)


class ConstructionYearRange(Base):
    __tablename__ = "construction_year_ranges"

    construction_year_range_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    start_year: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    end_year: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)


class InsulationStatus(Base):
    __tablename__ = "insulation_statuses"

    insulation_status_key: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
