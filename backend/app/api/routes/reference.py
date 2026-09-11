from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.db.session import get_db
from app.models.building import BuildingTypeTargetGroupMapping, ConstructionYearRange, InsulationStatus
from app.models.region import ClimateZone, SupportedRegion
from app.schemas.reference import (
    LOW_E_OPTIONS,
    REPRESENTATIVE_SPACE_TYPES,
    WALL_VISIBLE_ANOMALY_CONFIRM_OPTIONS,
    WINDOW_TYPE_OPTIONS,
    BuildingTypeOption,
    ConstructionYearRangeOption,
    OptionItem,
    RegionItem,
    RegionsResponse,
    ReferenceOptionsResponse,
)

router = APIRouter(tags=["reference"])

# db-spec.md의 building_type_target_group_mappings / construction_year_ranges /
# insulation_statuses에는 정책 U값 테이블과 달리 버전 컬럼이 없다. 실제 버전
# 관리가 필요해지면 그때 마이그레이션으로 추가한다 — 지금은 고정 문자열로 둔다.
OPTIONS_VERSION = "options-seed-v1"


@router.get("/regions", response_model=RegionsResponse)
def get_regions(db: DbSession = Depends(get_db)) -> RegionsResponse:
    rows = db.execute(
        select(SupportedRegion, ClimateZone)
        .join(ClimateZone, SupportedRegion.climate_zone_key == ClimateZone.climate_zone_key)
        .where(SupportedRegion.is_supported.is_(True))
    ).all()

    regions = [
        RegionItem(
            region_id=region.region_id,
            display_name=region.display_name,
            hdd_lookup_key=region.hdd_lookup_key,
            climate_zone=zone.climate_zone_key,
            climate_zone_description=zone.description,
            supported=region.is_supported,
        )
        for region, zone in rows
    ]

    # 시드 데이터는 한 번에 같은 버전으로 들어간다고 가정 — 첫 행의 버전을 대표값으로 쓴다.
    data_version = rows[0][0].region_data_version if rows else "unseeded"

    return RegionsResponse(data_version=data_version, regions=regions)


@router.get("/reference/options", response_model=ReferenceOptionsResponse)
def get_reference_options(db: DbSession = Depends(get_db)) -> ReferenceOptionsResponse:
    building_types = [
        BuildingTypeOption(
            value=row.building_type_key,
            label=row.display_name,
            u_value_reference_group=row.building_group_key,
        )
        for row in db.scalars(select(BuildingTypeTargetGroupMapping)).all()
    ]

    construction_year_ranges = [
        ConstructionYearRangeOption(
            value=row.construction_year_range_key,
            label=row.display_name,
            min_year=row.start_year,
            max_year=row.end_year,
        )
        for row in db.scalars(select(ConstructionYearRange)).all()
    ]

    wall_insulation_status_options = [
        OptionItem(value=row.insulation_status_key, label=row.display_name)
        for row in db.scalars(select(InsulationStatus)).all()
    ]

    return ReferenceOptionsResponse(
        options_version=OPTIONS_VERSION,
        building_types=building_types,
        representative_space_types=REPRESENTATIVE_SPACE_TYPES,
        window_type_options=WINDOW_TYPE_OPTIONS,
        low_e_options=LOW_E_OPTIONS,
        construction_year_ranges=construction_year_ranges,
        wall_insulation_status_options=wall_insulation_status_options,
        wall_visible_anomaly_confirm_options=WALL_VISIBLE_ANOMALY_CONFIRM_OPTIONS,
    )
