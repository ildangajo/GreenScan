"""진단 이력 CRUD DTO (api-spec.md 1.1, db-spec.md 9장, v8.1 신규).

confirmed_input/calculation_result의 정확한 내부 구조는 BE-C의 계산 엔진이
아직 확정하지 않았다. 그 결과를 그대로 받아 스냅샷으로 저장하는 게 이
계층의 역할이라, 내부 스키마를 여기서 강제하지 않고 임의 JSON으로 받는다.
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel


class DiagnosisCreateRequest(BaseModel):
    building_type_key: str
    region_id: str
    confirmed_input: dict[str, Any]
    calculation_result: dict[str, Any]
    calculation_version: str
    reference_data_version: str


class DiagnosisSummary(BaseModel):
    diagnosis_id: UUID
    building_type_key: str
    region_id: str
    created_at: datetime

    model_config = {"from_attributes": True}


class DiagnosisDetail(DiagnosisSummary):
    confirmed_input: dict[str, Any]
    calculation_result: dict[str, Any]
    calculation_version: str
    reference_data_version: str


class DiagnosisListResponse(BaseModel):
    diagnoses: list[DiagnosisSummary]
