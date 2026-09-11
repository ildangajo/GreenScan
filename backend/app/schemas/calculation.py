from pydantic import BaseModel


class ReferenceDataVersion(BaseModel):
    current_u_value_window: str
    current_u_value_wall: str
    target_u_value: str
    hdd: str
    # calc-v2(docs/result-screen-v9-design.md) — ⚠️ 이 세 값은 원문 미대조
    # 잠정 추정치(envelope-estimate-v1-unverified)다. seed_envelope_u_values.py
    # 주석 참고.
    current_u_value_ceiling: str
    current_u_value_floor: str
    current_u_value_door: str


class BaselineResult(BaseModel):
    window_heat_loss_kwh: float
    wall_heat_loss_kwh: float
    # calc-v2 신규 — 아래 세 값 포함 전 합계와의 구분을 위해 total은 항상
    # 5개 부위(창호/벽체/천장/바닥/문) 합계다.
    ceiling_heat_loss_kwh: float
    floor_heat_loss_kwh: float
    door_heat_loss_kwh: float
    total_heat_loss_kwh: float


class EnergyEfficiencyLevel(BaseModel):
    """calc-v2 — docs/result-screen-v9-design.md 1절. band_level 1(긴급)~5(매우 좋음).
    disclaimer는 PRD v8.3 원칙: 반드시 "참고용 추정치" 고지를 동반해야 한다는
    요구를 서버가 문구까지 같이 내려줘서 프론트가 누락하지 않게 한다.
    """

    band_level: int
    label: str
    kwh_per_m2: float
    disclaimer: str = "참고용 추정치이며 실제와 다를 수 있습니다."


class ScenarioResult(BaseModel):
    scenario_id: str
    name: str
    changed_components: list[str]
    annual_reduction_kwh: float
    reduction_rate: float
    priority: int


class WallAnomalyNotice(BaseModel):
    status: str
    message: str


class CalculateResponse(BaseModel):
    calculation_version: str
    reference_data_version: ReferenceDataVersion
    baseline: BaselineResult
    scenarios: list[ScenarioResult]
    wall_anomaly_notice: WallAnomalyNotice
    unit_scope_disclaimer: str
    bill_comparison: None = None
    # calc-v2 신규 필드
    efficiency_level: EnergyEfficiencyLevel
    # PRD v8.3-4: LLM 자유생성 없이 등급+1순위 시나리오를 템플릿에 꽂아 조립한 한 줄 요약.
    ai_summary: str
    # "누수" 우선순위 카드용 — 물리 계산 대상이 아니라 wall.visible_anomaly_confirmed
    # 후보를 그대로 노출한다("suspected"일 때만 "높음"으로 표시, PRD 원칙 5).
    leak_priority: str | None = None
