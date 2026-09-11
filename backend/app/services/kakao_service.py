"""카카오맵 주소 검색(지오코딩) — 서버 사이드 REST API 호출.

PRD v8.1 / api-spec.md 1.1: 검색 지원 지역은 서울만이다. 좌표 기반 반경 계산
대신, 카카오 주소 검색 응답의 행정구역명(`region_1depth_name`)이 서울인지로
판별한다 — 별도 좌표 경계 데이터 없이도 정확하고, 행정구역 자체가 기준이라
오차가 없다.

실제 호출로 확인한 값: 카카오 API는 "서울특별시"가 아니라 축약형 "서울"을
반환한다(2026-09-11 직접 검증, `https://dapi.kakao.com/v2/local/search/address.json`
응답의 `address.region_1depth_name`). 문서만 보고 "서울특별시"로 짐작해
비교했다가 실제로는 절대 매칭이 안 되는 버그가 있었어서, 실제 응답값 기준으로
고쳤다.
"""

import httpx

from app.core.config import settings

_KAKAO_ADDRESS_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/address.json"
_SEOUL_REGION_NAME = "서울"


class KakaoApiError(Exception):
    """카카오 API 호출 자체가 실패했을 때 (네트워크, 인증, 5xx 등)."""


class AddressNotFoundError(Exception):
    """주소 검색 결과가 없을 때."""


class GeocodeResult:
    def __init__(self, latitude: float, longitude: float, region_1depth_name: str, road_address: str | None):
        self.latitude = latitude
        self.longitude = longitude
        self.region_1depth_name = region_1depth_name
        self.road_address = road_address

    @property
    def is_seoul(self) -> bool:
        return self.region_1depth_name == _SEOUL_REGION_NAME


def geocode_address(address: str) -> GeocodeResult:
    try:
        response = httpx.get(
            _KAKAO_ADDRESS_SEARCH_URL,
            params={"query": address},
            headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
            timeout=10,
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        raise KakaoApiError(str(exc)) from exc

    documents = response.json().get("documents", [])
    if not documents:
        raise AddressNotFoundError(address)

    doc = documents[0]
    address_info = doc.get("road_address") or doc.get("address") or {}

    return GeocodeResult(
        latitude=float(doc["y"]),
        longitude=float(doc["x"]),
        region_1depth_name=address_info.get("region_1depth_name", ""),
        road_address=doc.get("road_address", {}).get("address_name") if doc.get("road_address") else None,
    )
