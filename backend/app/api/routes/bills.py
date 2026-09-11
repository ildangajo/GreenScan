from fastapi import APIRouter

from app.schemas.bill import BillCompareRequest, BillCompareResponse

router = APIRouter(prefix="/bills", tags=["bills"])

_COMPARISON_NOTE = "참고용 비교이며 핵심 계산 보정에는 사용되지 않았습니다."


@router.post("/compare", response_model=BillCompareResponse)
def compare_bill(payload: BillCompareRequest) -> BillCompareResponse:
    """api-spec.md 2.5: 고지서 참고 비교 (Should, MVP 후순위).

    단위 환산·원단위 비교 로직은 아직 정책 확정 전이라(PRD 원칙 3: 기준이
    모호할 때 임의로 확정하지 않는다) 실제 비교 계산은 하지 않는다. 요청
    계약만 먼저 고정해두고, 정책이 정해지면 comparison_result를 채운다.
    이 결과는 어떤 경우에도 diagnoses/calculate의 핵심 계산을 보정하지
    않는다.
    """
    del payload  # 현재는 요청 형태 검증까지만 — 실제 비교 로직 미구현
    return BillCompareResponse(comparison_note=_COMPARISON_NOTE, comparison_result=None)
