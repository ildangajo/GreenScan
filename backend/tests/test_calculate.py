"""POST /diagnoses/calculate 통합 테스트.

실제 시드된 기준 데이터(target/current U값, HDD, 지원지역)를 조회하므로
진짜 DB가 필요하다. test_db_connection.py와 동일하게 게이팅한다.

시드값 기준 (2026-09-11 기준 실제 시드):
- current_window_u_value(double, unknown) = 3.4
- current_wall_u_value(2016_2018, good) = 0.260
- target_window_u_value(apartment_group, jungbu-2) = 1.000
- target_wall_u_value(apartment_group, jungbu-2) = 0.170
- hdd(seoul) = 2380.1

calc-v2(docs/result-screen-v9-design.md, 2026-09-12) 추가 후에는 아래도 시드돼
있어야 한다 — 없으면 REFERENCE_DATA_MISSING(422)으로 막힌다:
- python -m app.db.seed.seed_envelope_u_values (천장/바닥/문 현재 U값)
- python -m app.db.seed.seed_energy_efficiency_bands (효율 레벨 LV.1~5 밴드)
"""

import copy
import os

import pytest

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run calculate integration tests against a real DB.",
)


def _valid_payload(**overrides):
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


def test_calculate_returns_baseline_and_scenarios(client):
    response = client.post("/api/v1/diagnoses/calculate", json=_valid_payload())

    assert response.status_code == 200
    body = response.json()

    # 직접 검산: U × area × 24 × hdd / 1000
    assert body["baseline"]["window_heat_loss_kwh"] == pytest.approx(3.4 * 3.6 * 24 * 2380.1 / 1000, rel=1e-6)
    assert body["baseline"]["wall_heat_loss_kwh"] == pytest.approx(0.260 * 8.4 * 24 * 2380.1 / 1000, rel=1e-6)
    # calc-v2(docs/result-screen-v9-design.md): total은 이제 창호+벽체뿐 아니라
    # 천장/바닥/문까지 5개 부위 합계다 — window+wall 합만으로는 더 이상 안 맞는다.
    assert body["baseline"]["total_heat_loss_kwh"] == pytest.approx(
        body["baseline"]["window_heat_loss_kwh"]
        + body["baseline"]["wall_heat_loss_kwh"]
        + body["baseline"]["ceiling_heat_loss_kwh"]
        + body["baseline"]["floor_heat_loss_kwh"]
        + body["baseline"]["door_heat_loss_kwh"],
        rel=1e-9,
    )

    assert len(body["scenarios"]) == 3
    scenario_ids = {s["scenario_id"] for s in body["scenarios"]}
    assert scenario_ids == {"window_upgrade", "wall_upgrade", "combined_upgrade"}

    # calc-v2 신규 필드도 항상 채워져야 한다.
    assert body["efficiency_level"]["band_level"] in range(1, 6)
    assert "참고용 추정치" in body["efficiency_level"]["disclaimer"]
    assert body["ai_summary"]


def test_lidar_and_manual_sources_return_the_same_calculation(client):
    """프론트가 확정한 수치가 같으면 입력 출처는 계산 결과에 영향을 주지 않는다."""
    manual_payload = _valid_payload()
    manual_payload["space"]["input_source"] = "manual"

    lidar_payload = copy.deepcopy(manual_payload)
    lidar_payload["space"]["input_source"] = "lidar"

    manual_response = client.post("/api/v1/diagnoses/calculate", json=manual_payload)
    lidar_response = client.post("/api/v1/diagnoses/calculate", json=lidar_payload)

    assert manual_response.status_code == 200
    assert lidar_response.status_code == 200
    assert lidar_response.json() == manual_response.json()


def test_scenario_priority_sorted_by_reduction_descending(client):
    response = client.post("/api/v1/diagnoses/calculate", json=_valid_payload())
    scenarios = response.json()["scenarios"]

    reductions = [s["annual_reduction_kwh"] for s in scenarios]
    assert reductions == sorted(reductions, reverse=True)
    assert [s["priority"] for s in scenarios] == [1, 2, 3]


def test_reduction_rate_denominator_is_baseline_total(client):
    response = client.post("/api/v1/diagnoses/calculate", json=_valid_payload())
    body = response.json()
    baseline_total = body["baseline"]["total_heat_loss_kwh"]

    for scenario in body["scenarios"]:
        expected_rate = scenario["annual_reduction_kwh"] / baseline_total
        assert scenario["reduction_rate"] == pytest.approx(expected_rate, rel=1e-9)


def test_wall_net_area_zero_or_negative_returns_422(client):
    response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_valid_payload(wall={
            "exterior_total_area_m2": 3.0,
            "insulation_status": "good",
            "visible_anomaly_confirmed": "none_observed",
            "input_source": "manual",
        }),
    )

    assert response.status_code == 422
    assert response.json()["detail"]["error_code"] == "WALL_NET_AREA_INVALID"


def test_unsupported_region_returns_400(client):
    response = client.post(
        "/api/v1/diagnoses/calculate", json=_valid_payload(location={"region_id": "busan"})
    )

    assert response.status_code == 400
    assert response.json()["detail"]["error_code"] == "UNSUPPORTED_REGION"


def test_invalid_building_type_returns_400(client):
    response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_valid_payload(
            building={
                "building_type": "commercial",
                "representative_space_type": "living_room",
                "construction_year_range": "2016_2018",
            }
        ),
    )

    assert response.status_code == 400
    assert response.json()["detail"]["error_code"] == "INVALID_ENUM_VALUE"


def test_missing_current_wall_u_value_returns_reference_data_missing(client):
    """insulation_status=none/partial은 의도적으로 시드하지 않았다 (db-spec.md 8장)."""
    response = client.post(
        "/api/v1/diagnoses/calculate",
        json=_valid_payload(
            wall={
                "exterior_total_area_m2": 12.0,
                "insulation_status": "none",
                "visible_anomaly_confirmed": "none_observed",
                "input_source": "manual",
            }
        ),
    )

    assert response.status_code == 422
    body = response.json()["detail"]
    assert body["error_code"] == "REFERENCE_DATA_MISSING"
    assert body["detail"]["missing"] == "current_wall_u_value"


def test_wall_anomaly_notice_does_not_affect_heat_loss(client):
    """PRD: 이상 흔적 여부는 안내 문구만 바꾸고 열손실 계산에는 영향을 주지 않는다."""
    none_observed = client.post(
        "/api/v1/diagnoses/calculate",
        json=_valid_payload(wall={
            "exterior_total_area_m2": 12.0,
            "insulation_status": "good",
            "visible_anomaly_confirmed": "none_observed",
            "input_source": "manual",
        }),
    ).json()
    suspected = client.post(
        "/api/v1/diagnoses/calculate",
        json=_valid_payload(wall={
            "exterior_total_area_m2": 12.0,
            "insulation_status": "good",
            "visible_anomaly_confirmed": "suspected",
            "input_source": "manual",
        }),
    ).json()

    assert none_observed["baseline"] == suspected["baseline"]
    assert none_observed["wall_anomaly_notice"]["status"] == "none_observed"
    assert suspected["wall_anomaly_notice"]["status"] == "suspected"
    assert none_observed["wall_anomaly_notice"]["message"] != suspected["wall_anomaly_notice"]["message"]
