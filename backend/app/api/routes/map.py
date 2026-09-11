from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.account import User
from app.models.region import SupportedRegion
from app.schemas.map import GeocodeResponse
from app.services.kakao_service import AddressNotFoundError, KakaoApiError, geocode_address

router = APIRouter(prefix="/map", tags=["map"])


@router.get("/geocode", response_model=GeocodeResponse)
def geocode(
    address: str,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> GeocodeResponse:
    """카카오맵으로 주소를 좌표로 바꾸고 서울 지원 지역 여부를 판별한다.

    PRD v8.1: 지도 검색은 서울만 지원한다. 서울 밖 주소는 좌표를 구했더라도
    UNSUPPORTED_REGION으로 처리한다 (api-spec.md 2.1의 UNSUPPORTED_REGION
    관례를 그대로 따름).
    """
    try:
        result = geocode_address(address)
    except AddressNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "ADDRESS_NOT_FOUND", "message": "주소를 찾을 수 없습니다."},
        ) from exc
    except KakaoApiError as exc:
        raise HTTPException(
            status_code=502,
            detail={"error_code": "KAKAO_API_ERROR", "message": "지도 서비스 호출에 실패했습니다."},
        ) from exc

    if not result.is_seoul:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "UNSUPPORTED_REGION",
                "message": "현재는 서울 지역만 지원합니다.",
                "detail": {"region_1depth_name": result.region_1depth_name},
            },
        )

    region = db.scalar(select(SupportedRegion).where(SupportedRegion.region_id == "seoul"))
    if region is None:
        # 기준 데이터(BE-C 시드) 미완료 상태 — 좌표는 서울이 맞지만 계산에 쓸
        # supported_regions 행이 아직 없다. api-spec.md의 REFERENCE_DATA_MISSING
        # 관례를 따른다.
        raise HTTPException(
            status_code=422,
            detail={
                "error_code": "REFERENCE_DATA_MISSING",
                "message": "서울 지역 기준 데이터가 아직 준비되지 않았습니다.",
                "detail": {"missing": "supported_regions.seoul"},
            },
        )

    return GeocodeResponse(
        region_id=region.region_id,
        hdd_lookup_key=region.hdd_lookup_key,
        latitude=result.latitude,
        longitude=result.longitude,
        road_address=result.road_address,
    )
