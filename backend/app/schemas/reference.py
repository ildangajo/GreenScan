from pydantic import BaseModel


class RegionItem(BaseModel):
    region_id: str
    display_name: str
    hdd_lookup_key: str
    climate_zone: str
    climate_zone_description: str
    supported: bool


class RegionsResponse(BaseModel):
    data_version: str
    regions: list[RegionItem]


class OptionItem(BaseModel):
    value: str
    label: str


class BuildingTypeOption(OptionItem):
    u_value_reference_group: str


class ConstructionYearRangeOption(BaseModel):
    value: str
    label: str
    min_year: int | None = None
    max_year: int | None = None


# api-spec.md 2.2: representative_space_types, window_type_options, low_e_options,
# wall_visible_anomaly_confirm_options는 db-spec.md에 별도 기준 데이터 테이블이
# 없다 — U값 정책의 조회 조건으로만 쓰이는 고정 키라 코드에 상수로 둔다.
# (construction_year_ranges, wall_insulation_status_options, building_types는
# 정책 확정이 필요해 DB에서 조회한다.)
REPRESENTATIVE_SPACE_TYPES: list[OptionItem] = [
    OptionItem(value="living_room", label="거실"),
    OptionItem(value="main_bedroom", label="주침실"),
    OptionItem(value="other", label="기타 대표 공간"),
]

WINDOW_TYPE_OPTIONS: list[OptionItem] = [
    OptionItem(value="single", label="단창"),
    OptionItem(value="double", label="복층창"),
    OptionItem(value="triple", label="삼중창"),
]

LOW_E_OPTIONS: list[OptionItem] = [
    OptionItem(value="yes", label="Low-E 적용"),
    OptionItem(value="no", label="Low-E 미적용"),
    OptionItem(value="unknown", label="모름"),
]

WALL_VISIBLE_ANOMALY_CONFIRM_OPTIONS: list[OptionItem] = [
    OptionItem(value="suspected", label="이상 흔적 있음 (현장 점검 권장)"),
    OptionItem(value="none_observed", label="이상 흔적 없음"),
]


class ReferenceOptionsResponse(BaseModel):
    options_version: str
    building_types: list[BuildingTypeOption]
    representative_space_types: list[OptionItem]
    window_type_options: list[OptionItem]
    low_e_options: list[OptionItem]
    construction_year_ranges: list[ConstructionYearRangeOption]
    wall_insulation_status_options: list[OptionItem]
    wall_visible_anomaly_confirm_options: list[OptionItem]
