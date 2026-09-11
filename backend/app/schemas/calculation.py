from pydantic import BaseModel


class ReferenceDataVersion(BaseModel):
    current_u_value_window: str
    current_u_value_wall: str
    target_u_value: str
    hdd: str


class BaselineResult(BaseModel):
    window_heat_loss_kwh: float
    wall_heat_loss_kwh: float
    total_heat_loss_kwh: float


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
