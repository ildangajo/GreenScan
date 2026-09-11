"""진단 이력 저장/조회, 즐겨찾기 API 통합 테스트.

실제 users/diagnoses/favorites 행을 쓰므로 진짜 DB가 필요하다.
test_db_connection.py와 동일하게 RUN_DB_CONNECTION_TEST로 게이팅한다.
"""

import os
import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import delete

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run diagnoses/favorites integration tests against a real DB.",
)


@pytest.fixture
def auth_headers_and_user():
    from app.core.security import hash_password
    from app.db.session import SessionLocal
    from app.models.account import Favorite, Session as SessionModel, User
    from app.models.account import Diagnosis

    db = SessionLocal()
    login_id = f"test-{uuid.uuid4().hex[:8]}"
    user = User(
        login_id=login_id,
        password_hash=hash_password("irrelevant-for-this-test"),
        created_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    from app.core.security import generate_session_token

    token = generate_session_token()
    db.add(
        SessionModel(
            session_token=token,
            user_id=user.user_id,
            expires_at=datetime.now(timezone.utc).replace(year=2099),
        )
    )
    db.commit()

    yield {"Authorization": f"Bearer {token}"}, user.user_id

    db.execute(delete(Favorite).where(Favorite.user_id == user.user_id))
    db.execute(delete(Diagnosis).where(Diagnosis.user_id == user.user_id))
    db.execute(delete(SessionModel).where(SessionModel.user_id == user.user_id))
    db.execute(delete(User).where(User.user_id == user.user_id))
    db.commit()
    db.close()


def _diagnosis_payload():
    return {
        "building_type_key": "apartment",
        "region_id": "seoul",
        "confirmed_input": {"window": {"total_area_m2": 3.6}},
        "calculation_result": {"baseline": {"total_heat_loss_kwh": 1352.5}},
        "calculation_version": "calc-v1",
        "reference_data_version": "ref-v1",
    }


def test_create_and_get_diagnosis(client, auth_headers_and_user):
    headers, _ = auth_headers_and_user

    create_response = client.post("/api/v1/diagnoses", json=_diagnosis_payload(), headers=headers)
    assert create_response.status_code == 201
    diagnosis_id = create_response.json()["diagnosis_id"]

    get_response = client.get(f"/api/v1/diagnoses/{diagnosis_id}", headers=headers)
    assert get_response.status_code == 200
    assert get_response.json()["calculation_result"]["baseline"]["total_heat_loss_kwh"] == 1352.5


def test_list_diagnoses_only_returns_own(client, auth_headers_and_user):
    headers, _ = auth_headers_and_user
    client.post("/api/v1/diagnoses", json=_diagnosis_payload(), headers=headers)

    list_response = client.get("/api/v1/diagnoses", headers=headers)
    assert list_response.status_code == 200
    assert len(list_response.json()["diagnoses"]) == 1


def test_get_diagnosis_not_owned_returns_404(client, auth_headers_and_user):
    headers, _ = auth_headers_and_user
    random_id = str(uuid.uuid4())

    response = client.get(f"/api/v1/diagnoses/{random_id}", headers=headers)
    assert response.status_code == 404
    assert response.json()["detail"]["error_code"] == "DIAGNOSIS_NOT_FOUND"


def test_diagnoses_require_auth(client):
    response = client.get("/api/v1/diagnoses")
    assert response.status_code == 401


def test_favorite_lifecycle(client, auth_headers_and_user):
    headers, _ = auth_headers_and_user
    diagnosis_id = client.post("/api/v1/diagnoses", json=_diagnosis_payload(), headers=headers).json()[
        "diagnosis_id"
    ]

    create_response = client.post("/api/v1/favorites", json={"diagnosis_id": diagnosis_id}, headers=headers)
    assert create_response.status_code == 201
    favorite_id = create_response.json()["favorite_id"]

    list_response = client.get("/api/v1/favorites", headers=headers)
    assert len(list_response.json()["favorites"]) == 1

    delete_response = client.delete(f"/api/v1/favorites/{favorite_id}", headers=headers)
    assert delete_response.status_code == 204

    list_after_delete = client.get("/api/v1/favorites", headers=headers)
    assert len(list_after_delete.json()["favorites"]) == 0


def test_favorite_on_unowned_diagnosis_returns_404(client, auth_headers_and_user):
    headers, _ = auth_headers_and_user
    random_id = str(uuid.uuid4())

    response = client.post("/api/v1/favorites", json={"diagnosis_id": random_id}, headers=headers)
    assert response.status_code == 404
    assert response.json()["detail"]["error_code"] == "DIAGNOSIS_NOT_FOUND"
