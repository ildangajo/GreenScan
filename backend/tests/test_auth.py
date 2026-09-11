"""로그인/로그아웃 API 통합 테스트.

실제 Postgres에 users/sessions 행을 직접 쓰고 지우므로, 다른 단위 테스트와
달리 진짜 DB가 필요하다. test_db_connection.py와 동일한 방식으로 게이팅한다.
"""

import os
import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import delete

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run auth integration tests against a real DB.",
)


@pytest.fixture
def seeded_user():
    from app.core.security import hash_password
    from app.db.session import SessionLocal
    from app.models.account import Session as SessionModel, User

    db = SessionLocal()
    login_id = f"test-{uuid.uuid4().hex[:8]}"
    password = "correct-horse-battery-staple"
    user = User(
        login_id=login_id,
        password_hash=hash_password(password),
        display_name="테스트 계정",
        created_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    yield login_id, password

    db.execute(delete(SessionModel).where(SessionModel.user_id == user.user_id))
    db.execute(delete(User).where(User.user_id == user.user_id))
    db.commit()
    db.close()


def test_login_with_valid_credentials_issues_session(client, seeded_user):
    login_id, password = seeded_user

    response = client.post("/api/v1/auth/login", json={"login_id": login_id, "password": password})

    assert response.status_code == 200
    body = response.json()
    assert body["session_token"]
    assert body["display_name"] == "테스트 계정"


def test_login_with_wrong_password_is_rejected(client, seeded_user):
    login_id, _ = seeded_user

    response = client.post("/api/v1/auth/login", json={"login_id": login_id, "password": "wrong-password"})

    assert response.status_code == 401
    assert response.json()["detail"]["error_code"] == "INVALID_CREDENTIALS"


def test_login_with_unknown_login_id_is_rejected(client):
    response = client.post(
        "/api/v1/auth/login", json={"login_id": "no-such-user", "password": "whatever"}
    )

    assert response.status_code == 401
    assert response.json()["detail"]["error_code"] == "INVALID_CREDENTIALS"


def test_logout_invalidates_session(client, seeded_user):
    login_id, password = seeded_user
    login_response = client.post("/api/v1/auth/login", json={"login_id": login_id, "password": password})
    token = login_response.json()["session_token"]

    logout_response = client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert logout_response.status_code == 204

    reused_response = client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert reused_response.status_code == 401
    assert reused_response.json()["detail"]["error_code"] == "SESSION_INVALID"


def test_protected_endpoint_without_token_is_rejected(client):
    response = client.post("/api/v1/auth/logout")

    assert response.status_code == 401
    assert response.json()["detail"]["error_code"] == "UNAUTHORIZED"
