"""PRD 12장 통합 테스트 시나리오 중, 지금까지의 단위/도메인 테스트가 커버하지
못한 "여러 엔드포인트를 가로지르는" 흐름만 모아서 검증한다.

각 도메인 자체의 세부 규칙(입력 검증, 실패 폴백 등)은 이미 다른 테스트
파일에서 다룬다 — 여기서는 그 도메인들이 실제로 이어붙었을 때도 맞는지만
본다.

- 시나리오 1(기본 완료): 로그인 → 사진 분석(모킹) → 사용자 확정 → 계산 →
  이력 저장 → 조회 → 즐겨찾기
- 시나리오 2(아파트 기준 매핑): 같은 입력이어도 building_type에 따라
  target_u_value_policies의 공동주택/공동주택외 그룹이 실제로 달라져
  계산 결과가 달라지는지
- 시나리오 3(AI 수정 반영): Vision이 복층창(double) 후보를 반환해도
  사용자가 단창(single)으로 확정하면 계산은 단창 U값(6.10)을 쓰는지 —
  candidate 값이 계산에 새어 들어가지 않는지

실제 DB와 시드 데이터가 필요하므로 test_db_connection.py와 동일하게
RUN_DB_CONNECTION_TEST로 게이팅한다. Vision은 실제 OpenAI를 호출하지
않고 모킹한다.
"""

import json
import os
import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from sqlalchemy import delete

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run integration flow tests against a real DB.",
)


@pytest.fixture
def auth_headers():
    from app.core.security import generate_session_token, hash_password
    from app.db.session import SessionLocal
    from app.models.account import Diagnosis, Favorite, Session as SessionModel, User

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

    db.execute(delete(Favorite).where(Favorite.user_id == user.user_id))
    db.execute(delete(Diagnosis).where(Diagnosis.user_id == user.user_id))
    db.execute(delete(SessionModel).where(SessionModel.user_id == user.user_id))
    db.execute(delete(User).where(User.user_id == user.user_id))
    db.commit()
    db.close()


def _base_calculate_payload(**overrides):
    payload = {
        "building": {
            "building_type": "apartment",
            "representative_space_type": "living_room",
            "construction_year_range": "2016_2018",
        },
        "space": {
            "width_m": 4.2,
            "depth_m": 3.5,
            "height_m": 2.4,
            "floor_area_m2": 14.7,
            "input_source": "manual",
        },
        "window": {
            "total_area_m2": 3.6,
            "window_type": "double",
            "low_e": "unknown",
            "input_source": "user_corrected",
        },
        "wall": {
            "exterior_total_area_m2": 12.0,
            "insulation_status": "good",
            "visible_anomaly_confirmed": "none_observed",
            "input_source": "manual",
        },
        "location": {"region_id": "seoul"},
        "bill": None,
    }
    payload.update(overrides)
    return payload


def test_full_flow_analyze_confirm_calculate_save_favorite(client, valid_jpeg_bytes, auth_headers):
    """시나리오 1: 사진 분석 → 사용자 확정 → 계산 → 저장 → 조회 → 즐겨찾기."""
    mock_vision_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "window",
            "window_type_candidate": "double",
            "visible_anomaly_candidate": "not_applicable",
            "reason_summary": "복층창으로 보입니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_vision_response):
        analyze_response = client.post(
            "/api/v1/photos/analyze",
            data={"category": "window"},
            files={"image": ("window.jpg", valid_jpeg_bytes, "image/jpeg")},
        )
    assert analyze_response.status_code == 200
    candidate = analyze_response.json()
    assert candidate["needs_user_confirmation"] is True

    # 사용자가 AI 후보(double)를 그대로 확정했다고 가정하고 계산 요청 조립
    calc_response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_base_calculate_payload(
            window={
                "total_area_m2": 3.6,
                "window_type": candidate["window_type_candidate"],
                "low_e": "unknown",
                "input_source": "user_corrected",
            }
        ),
    )
    assert calc_response.status_code == 200
    calc_body = calc_response.json()

    save_response = client.post(
        "/api/v1/diagnoses",
        json={
            "building_type_key": "apartment",
            "region_id": "seoul",
            "confirmed_input": _base_calculate_payload(),
            "calculation_result": calc_body,
            "calculation_version": calc_body["calculation_version"],
            "reference_data_version": json.dumps(calc_body["reference_data_version"]),
        },
        headers=auth_headers,
    )
    assert save_response.status_code == 201
    diagnosis_id = save_response.json()["diagnosis_id"]

    get_response = client.get(f"/api/v1/diagnoses/{diagnosis_id}", headers=auth_headers)
    assert get_response.status_code == 200
    assert get_response.json()["calculation_result"]["baseline"]["total_heat_loss_kwh"] == pytest.approx(
        calc_body["baseline"]["total_heat_loss_kwh"]
    )

    favorite_response = client.post(
        "/api/v1/favorites", json={"diagnosis_id": diagnosis_id}, headers=auth_headers
    )
    assert favorite_response.status_code == 201

    list_response = client.get("/api/v1/favorites", headers=auth_headers)
    assert len(list_response.json()["favorites"]) == 1


def test_apartment_vs_detached_use_different_target_group(client):
    """시나리오 2: building_type에 따라 공동주택/공동주택외 목표 U값 그룹이 실제로 갈린다."""
    apartment_response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_base_calculate_payload(
            building={
                "building_type": "apartment",
                "representative_space_type": "living_room",
                "construction_year_range": "2016_2018",
            }
        ),
    )
    detached_response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_base_calculate_payload(
            building={
                "building_type": "detached_multi_household",
                "representative_space_type": "living_room",
                "construction_year_range": "2016_2018",
            }
        ),
    )

    assert apartment_response.status_code == 200
    assert detached_response.status_code == 200

    # 현재 U값(창호/벽체)은 건물유형과 무관하게 동일하므로 baseline은 같아야 한다.
    apt_baseline = apartment_response.json()["baseline"]["total_heat_loss_kwh"]
    det_baseline = detached_response.json()["baseline"]["total_heat_loss_kwh"]
    assert apt_baseline == pytest.approx(det_baseline)

    # 공동주택(아파트) 목표 U값이 더 낮아(엄격) 개선 시나리오 절감량이 더 커야 한다.
    apt_combined = next(
        s for s in apartment_response.json()["scenarios"] if s["scenario_id"] == "combined_upgrade"
    )
    det_combined = next(
        s for s in detached_response.json()["scenarios"] if s["scenario_id"] == "combined_upgrade"
    )
    assert apt_combined["annual_reduction_kwh"] > det_combined["annual_reduction_kwh"]


def test_ai_window_candidate_does_not_leak_into_calculation_without_confirmation(client, valid_jpeg_bytes):
    """시나리오 3: AI가 복층창(double)을 반환해도, 사용자가 단창(single)으로 확정하면
    계산은 반드시 단창 U값을 쓴다 — AI 후보가 계산에 직접 흘러들어가지 않는다."""
    mock_vision_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "window",
            "window_type_candidate": "double",
            "visible_anomaly_candidate": "not_applicable",
            "reason_summary": "복층창 후보로 보이나 사용자 확인이 필요합니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_vision_response):
        analyze_response = client.post(
            "/api/v1/photos/analyze",
            data={"category": "window"},
            files={"image": ("window.jpg", valid_jpeg_bytes, "image/jpeg")},
        )
    candidate = analyze_response.json()
    assert candidate["window_type_candidate"] == "double"

    # 사용자가 AI 후보를 무시하고 단창으로 직접 수정해 확정했다고 가정
    user_confirmed_window_type = "single"
    assert user_confirmed_window_type != candidate["window_type_candidate"]

    calc_response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_base_calculate_payload(
            window={
                "total_area_m2": 3.6,
                "window_type": user_confirmed_window_type,
                "low_e": "unknown",
                "input_source": "user_corrected",
            }
        ),
    )
    assert calc_response.status_code == 200
    # single/unknown 현재 U값은 6.10 — double/unknown(3.4)이 아니라 이 값으로 계산됐는지 확인
    expected_window_heat_loss = 6.10 * 3.6 * 24 * 2380.1 / 1000
    assert calc_response.json()["baseline"]["window_heat_loss_kwh"] == pytest.approx(
        expected_window_heat_loss, rel=1e-6
    )
