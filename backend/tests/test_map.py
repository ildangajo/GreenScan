"""GET /map/geocode 테스트.

실제 카카오 API는 호출하지 않는다 — app.services.kakao_service.geocode_address만
모킹한다. Kakao가 실제로 반환하는 region_1depth_name이 "서울특별시"가 아니라
축약형 "서울"이라는 사실을 2026-09-11에 실호출로 확인했고(kakao_service.py
docstring 참고), 이 테스트로 그 값을 고정해둔다.

로그인이 필요하므로 auth 관련 fixture는 test_auth.py와 동일한 패턴을 쓴다.
"""

import os
import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from sqlalchemy import delete

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run map integration tests against a real DB.",
)


@pytest.fixture
def auth_headers():
    from app.core.security import generate_session_token, hash_password
    from app.db.session import SessionLocal
    from app.models.account import Session as SessionModel, User

    db = SessionLocal()
    login_id = f"test-{uuid.uuid4().hex[:8]}"
    user = User(
        login_id=login_id,
        password_hash=hash_password("irrelevant"),
        created_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = generate_session_token()
    db.add(
        SessionModel(
            session_token=token,
            user_id=user.user_id,
            expires_at=datetime.now(timezone.utc).replace(year=2099),
        )
    )
    db.commit()

    yield {"Authorization": f"Bearer {token}"}

    db.execute(delete(SessionModel).where(SessionModel.user_id == user.user_id))
    db.execute(delete(User).where(User.user_id == user.user_id))
    db.commit()
    db.close()


def _mock_result(region_1depth_name: str):
    from app.services.kakao_service import GeocodeResult

    return GeocodeResult(
        latitude=37.5,
        longitude=127.0,
        region_1depth_name=region_1depth_name,
        road_address="테스트 주소",
    )


def test_geocode_requires_auth(client):
    response = client.get("/api/v1/map/geocode", params={"address": "아무거나"})
    assert response.status_code == 401


def test_seoul_address_without_seeded_region_returns_reference_data_missing(client, auth_headers):
    # region_1depth_name이 "서울"이어야 서울로 인식한다 — "서울특별시"였다면 이 테스트는
    # UNSUPPORTED_REGION으로 잘못 떨어져서 회귀를 잡아낸다.
    with patch("app.api.routes.map.geocode_address", return_value=_mock_result("서울")):
        response = client.get(
            "/api/v1/map/geocode", params={"address": "서울특별시 중구 세종대로 110"}, headers=auth_headers
        )

    # supported_regions.seoul이 아직 시드되지 않은 환경이면 422, 시드돼 있으면 200 —
    # 둘 다 "서울로 정확히 인식했다"는 것의 증거이므로 UNSUPPORTED_REGION만 아니면 된다.
    assert response.status_code in (200, 422)
    if response.status_code == 422:
        assert response.json()["detail"]["error_code"] == "REFERENCE_DATA_MISSING"


def test_non_seoul_address_is_rejected(client, auth_headers):
    with patch("app.api.routes.map.geocode_address", return_value=_mock_result("부산")):
        response = client.get(
            "/api/v1/map/geocode", params={"address": "부산광역시 연제구 중앙대로 1001"}, headers=auth_headers
        )

    assert response.status_code == 400
    body = response.json()["detail"]
    assert body["error_code"] == "UNSUPPORTED_REGION"
    assert body["detail"]["region_1depth_name"] == "부산"


def test_address_not_found_returns_404(client, auth_headers):
    from app.services.kakao_service import AddressNotFoundError

    with patch("app.api.routes.map.geocode_address", side_effect=AddressNotFoundError("no such address")):
        response = client.get("/api/v1/map/geocode", params={"address": "존재하지않는주소"}, headers=auth_headers)

    assert response.status_code == 404
    assert response.json()["detail"]["error_code"] == "ADDRESS_NOT_FOUND"


def test_kakao_api_failure_returns_502(client, auth_headers):
    from app.services.kakao_service import KakaoApiError

    with patch("app.api.routes.map.geocode_address", side_effect=KakaoApiError("boom")):
        response = client.get("/api/v1/map/geocode", params={"address": "아무 주소"}, headers=auth_headers)

    assert response.status_code == 502
    assert response.json()["detail"]["error_code"] == "KAKAO_API_ERROR"
