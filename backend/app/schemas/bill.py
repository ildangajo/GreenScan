from pydantic import BaseModel


class BillCompareRequest(BaseModel):
    energy_source: str
    usage_period: str
    usage_amount: float
    unit: str
    baseline_total_heat_loss_kwh: float


class BillCompareResponse(BaseModel):
    comparison_note: str
    comparison_result: None = None
