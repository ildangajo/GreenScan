from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DbSession

from app.db.session import get_db
from app.schemas.calculation import CalculateResponse
from app.schemas.diagnosis import CalculateRequest, WallNetAreaInvalidError
from app.services.calculation_service import (
    InvalidEnumValueError,
    ReferenceDataMissingError,
    UnsupportedRegionError,
    calculate,
)

router = APIRouter(prefix="/diagnoses", tags=["diagnoses"])


@router.post("/calculate", response_model=CalculateResponse)
def calculate_diagnosis(payload: CalculateRequest, db: DbSession = Depends(get_db)) -> CalculateResponse:
    """PRD 9.1: 계산 API는 사용자 확정값만 받는다. 로그인 여부와 무관하게 동작한다 —
    결과를 계정에 저장하려면 별도로 POST /diagnoses를 호출해야 한다(api-spec.md 1.1)."""
    try:
        return calculate(payload, db)
    except WallNetAreaInvalidError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "error_code": "WALL_NET_AREA_INVALID",
                "message": "외기 접촉 벽체 순면적이 0 이하입니다. 입력을 다시 확인해주세요.",
                "detail": {"wall_net_area_m2": exc.wall_net_area_m2},
            },
        ) from exc
    except UnsupportedRegionError as exc:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "UNSUPPORTED_REGION", "message": "지원하지 않는 지역입니다."},
        ) from exc
    except InvalidEnumValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_ENUM_VALUE",
                "message": f"{exc.field}에 유효하지 않은 값입니다.",
                "detail": {"field": exc.field, "value": exc.value},
            },
        ) from exc
    except ReferenceDataMissingError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "error_code": "REFERENCE_DATA_MISSING",
                "message": "계산에 필요한 기준 데이터가 아직 준비되지 않았습니다.",
                "detail": {"missing": exc.missing},
            },
        ) from exc
