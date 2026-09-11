from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.account import Diagnosis, User
from app.schemas.diagnosis_history import (
    DiagnosisCreateRequest,
    DiagnosisDetail,
    DiagnosisListResponse,
    DiagnosisSummary,
)

router = APIRouter(prefix="/diagnoses", tags=["diagnoses"])


def _get_owned_diagnosis(diagnosis_id: UUID, current_user: User, db: DbSession) -> Diagnosis:
    diagnosis = db.get(Diagnosis, diagnosis_id)
    # 존재하지 않는 것과 남의 것인 경우를 구분하지 않는다 — ID 추측으로 다른
    # 사용자의 진단 존재 여부를 알아낼 수 없게 한다.
    if diagnosis is None or diagnosis.user_id != current_user.user_id:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "DIAGNOSIS_NOT_FOUND", "message": "진단 기록을 찾을 수 없습니다."},
        )
    return diagnosis


@router.get("", response_model=DiagnosisListResponse)
def list_diagnoses(
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> DiagnosisListResponse:
    rows = db.scalars(
        select(Diagnosis)
        .where(Diagnosis.user_id == current_user.user_id)
        .order_by(Diagnosis.created_at.desc())
    ).all()
    return DiagnosisListResponse(diagnoses=[DiagnosisSummary.model_validate(row) for row in rows])


@router.get("/{diagnosis_id}", response_model=DiagnosisDetail)
def get_diagnosis(
    diagnosis_id: UUID,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> DiagnosisDetail:
    diagnosis = _get_owned_diagnosis(diagnosis_id, current_user, db)
    return DiagnosisDetail.model_validate(diagnosis)


@router.post("", response_model=DiagnosisDetail, status_code=201)
def create_diagnosis(
    payload: DiagnosisCreateRequest,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> DiagnosisDetail:
    """계산 결과를 계정에 귀속해 저장한다.

    api-spec.md 1.1: 저장 시점(계산 즉시 자동 vs 사용자가 명시적으로 버튼을
    누름)은 아직 정책 확정 전이라, 이 엔드포인트는 "이미 계산된 결과를
    명시적으로 저장 요청"하는 형태로 만들었다 — 계산 엔진(BE-C)이 완성되면
    프론트가 계산 응답을 그대로 이 바디에 담아 호출하거나, 자동 저장으로
    정책이 정해지면 계산 엔드포인트 내부에서 이 로직을 재사용하면 된다.
    원본 사진은 이 요청 바디 어디에도 포함하지 않는다 (PRD v8.1).
    """
    diagnosis = Diagnosis(
        user_id=current_user.user_id,
        building_type_key=payload.building_type_key,
        region_id=payload.region_id,
        confirmed_input=payload.confirmed_input,
        calculation_result=payload.calculation_result,
        calculation_version=payload.calculation_version,
        reference_data_version=payload.reference_data_version,
        created_at=datetime.now(timezone.utc),
    )
    db.add(diagnosis)
    db.commit()
    db.refresh(diagnosis)
    return DiagnosisDetail.model_validate(diagnosis)
