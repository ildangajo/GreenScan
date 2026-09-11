"""PRD 7.4 / api-spec.md 2.4: 연간 열손실 계산 엔진.

annual_heat_loss_kwh = u_value × area_m2 × 24 × hdd ÷ 1000

계산식 자체는 이 파일이 유일한 구현이다. 시나리오 정의(창호개선/벽체개선/
복합개선)는 PRD가 예시로 든 3개를 그대로 하드코딩했다 — calculation_policies
등 DB 정책 테이블은 아직 이 버전에서 사용하지 않는다(PRD 9.2: 계산식은
서버 코드가 수행하고, 정책 테이블은 버전 식별용일 뿐 계산 로직을 대신하지
않는다).

기준 데이터 조회가 하나라도 실패하면 임의 대체값을 쓰지 않고
ReferenceDataMissingError를 던져 계산을 중단한다 (db-spec.md 2.2 규칙).
"""

from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.models.building import BuildingTypeTargetGroupMapping, ConstructionYearRange
from app.models.region import HddValue, SupportedRegion
from app.models.reference_document import ReferenceDocument
from app.models.u_value_policy import CurrentWallUValuePolicy, CurrentWindowUValuePolicy, TargetUValuePolicy
from app.schemas.calculation import (
    BaselineResult,
    CalculateResponse,
    ReferenceDataVersion,
    ScenarioResult,
    WallAnomalyNotice,
)
from app.schemas.diagnosis import CalculateRequest, WallNetAreaInvalidError, check_wall_net_area

CALCULATION_VERSION = "calc-v1"

_UNIT_SCOPE_DISCLAIMER = (
    "이 결과는 대표 공간 1개 기준 비공식 추정치입니다. 천장, 바닥, 환기, 침기, 일사, "
    "난방기기 효율, 사용 습관은 포함하지 않습니다."
)

_WALL_ANOMALY_MESSAGES = {
    "suspected": "사진상 이상 흔적이 확인되어 별도 현장 점검을 권장합니다. 이 값은 열손실 수치에 영향을 주지 않습니다.",
    "none_observed": "사진상 뚜렷한 이상 흔적은 확인되지 않았습니다. 이 값은 열손실 수치에 영향을 주지 않습니다.",
}


class UnsupportedRegionError(Exception):
    pass


class InvalidEnumValueError(Exception):
    def __init__(self, field: str, value: str):
        self.field = field
        self.value = value
        super().__init__(f"{field}에 유효하지 않은 값입니다: {value}")


class ReferenceDataMissingError(Exception):
    def __init__(self, missing: str):
        self.missing = missing
        super().__init__(f"기준 데이터를 찾을 수 없습니다: {missing}")


def _annual_heat_loss_kwh(u_value: float, area_m2: float, hdd: float) -> float:
    return float(u_value) * area_m2 * 24 * float(hdd) / 1000


def calculate(request: CalculateRequest, db: DbSession) -> CalculateResponse:
    # 1. 벽체 순면적 검증 — WallNetAreaInvalidError는 라우터에서 422로 매핑한다.
    wall_net_area_m2 = check_wall_net_area(request)
    window_area_m2 = request.window.total_area_m2

    # 2. 지역 → HDD
    region = db.get(SupportedRegion, request.location.region_id)
    if region is None or not region.is_supported:
        raise UnsupportedRegionError(request.location.region_id)

    hdd_value = db.get(HddValue, region.hdd_lookup_key)
    if hdd_value is None:
        raise ReferenceDataMissingError("hdd")
    hdd_doc = db.get(ReferenceDocument, hdd_value.reference_document_id)

    # 3. 건물 유형 → 목표 U값 기준 그룹
    mapping = db.get(BuildingTypeTargetGroupMapping, request.building.building_type)
    if mapping is None:
        raise InvalidEnumValueError("building.building_type", request.building.building_type)

    # 4. 준공연도 구간 키 유효성 (current_wall 조회 전에 먼저 존재 여부 확인)
    if db.get(ConstructionYearRange, request.building.construction_year_range) is None:
        raise InvalidEnumValueError("building.construction_year_range", request.building.construction_year_range)

    # 5. 현재 추정 U값 (창호, 벽체)
    current_window_policy = db.scalar(
        select(CurrentWindowUValuePolicy).where(
            CurrentWindowUValuePolicy.window_type_key == request.window.window_type.value,
            CurrentWindowUValuePolicy.low_e_key == request.window.low_e.value,
        )
    )
    if current_window_policy is None:
        raise ReferenceDataMissingError("current_window_u_value")

    current_wall_policy = db.scalar(
        select(CurrentWallUValuePolicy).where(
            CurrentWallUValuePolicy.construction_year_range_key == request.building.construction_year_range,
            CurrentWallUValuePolicy.insulation_status_key == request.wall.insulation_status.value,
        )
    )
    if current_wall_policy is None:
        raise ReferenceDataMissingError("current_wall_u_value")

    # 6. 개선 목표 U값 (창호, 벽체) — 기후구역 범위로 조회
    target_window_policy = db.scalar(
        select(TargetUValuePolicy).where(
            TargetUValuePolicy.building_group_key == mapping.building_group_key,
            TargetUValuePolicy.component_key == "window",
            TargetUValuePolicy.climate_zone_key == region.climate_zone_key,
        )
    )
    if target_window_policy is None:
        raise ReferenceDataMissingError("target_window_u_value")

    target_wall_policy = db.scalar(
        select(TargetUValuePolicy).where(
            TargetUValuePolicy.building_group_key == mapping.building_group_key,
            TargetUValuePolicy.component_key == "wall",
            TargetUValuePolicy.climate_zone_key == region.climate_zone_key,
        )
    )
    if target_wall_policy is None:
        raise ReferenceDataMissingError("target_wall_u_value")

    # 7. 기준선 계산
    hdd = hdd_value.hdd_value_k_day
    baseline_window = _annual_heat_loss_kwh(current_window_policy.u_value_w_m2k, window_area_m2, hdd)
    baseline_wall = _annual_heat_loss_kwh(current_wall_policy.u_value_w_m2k, wall_net_area_m2, hdd)
    baseline_total = baseline_window + baseline_wall

    # 8. 시나리오 계산 (PRD 7.5: 창호개선/벽체개선/복합개선)
    target_window_heat_loss = _annual_heat_loss_kwh(target_window_policy.u_value_w_m2k, window_area_m2, hdd)
    target_wall_heat_loss = _annual_heat_loss_kwh(target_wall_policy.u_value_w_m2k, wall_net_area_m2, hdd)

    scenario_defs = [
        ("window_upgrade", "창호 개선", ["window"], baseline_total - (target_window_heat_loss + baseline_wall)),
        ("wall_upgrade", "벽체 개선", ["wall"], baseline_total - (baseline_window + target_wall_heat_loss)),
        (
            "combined_upgrade",
            "복합 개선",
            ["window", "wall"],
            baseline_total - (target_window_heat_loss + target_wall_heat_loss),
        ),
    ]

    # 절감량 내림차순으로 우선순위 부여 (PRD: priority는 annual_reduction_kwh 내림차순)
    scenario_defs.sort(key=lambda s: s[3], reverse=True)

    scenarios = [
        ScenarioResult(
            scenario_id=scenario_id,
            name=name,
            changed_components=changed_components,
            annual_reduction_kwh=reduction,
            reduction_rate=reduction / baseline_total if baseline_total > 0 else 0.0,
            priority=i + 1,
        )
        for i, (scenario_id, name, changed_components, reduction) in enumerate(scenario_defs)
    ]

    anomaly_status = request.wall.visible_anomaly_confirmed.value
    wall_anomaly_notice = WallAnomalyNotice(status=anomaly_status, message=_WALL_ANOMALY_MESSAGES[anomaly_status])

    return CalculateResponse(
        calculation_version=CALCULATION_VERSION,
        reference_data_version=ReferenceDataVersion(
            current_u_value_window=current_window_policy.policy_version,
            current_u_value_wall=current_wall_policy.policy_version,
            # target_u_value_policies에는 자체 policy_version 컬럼이 없어(db-spec.md 3.12),
            # 대신 연결된 출처 문서의 버전을 쓴다.
            target_u_value=(db.get(ReferenceDocument, target_window_policy.reference_document_id)).reference_version,
            hdd=hdd_doc.reference_version if hdd_doc else "unknown",
        ),
        baseline=BaselineResult(
            window_heat_loss_kwh=baseline_window,
            wall_heat_loss_kwh=baseline_wall,
            total_heat_loss_kwh=baseline_total,
        ),
        scenarios=scenarios,
        wall_anomaly_notice=wall_anomaly_notice,
        unit_scope_disclaimer=_UNIT_SCOPE_DISCLAIMER,
        bill_comparison=None,
    )


__all__ = [
    "calculate",
    "UnsupportedRegionError",
    "InvalidEnumValueError",
    "ReferenceDataMissingError",
    "WallNetAreaInvalidError",
]
