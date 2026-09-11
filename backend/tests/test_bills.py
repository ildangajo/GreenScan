"""POST /bills/compare 테스트.

api-spec.md 2.5: 단위 환산/비교 로직은 정책 확정 전이라, 이번 버전은
요청 계약을 검증하고 항상 고정된 비확정 고지 문구를 반환한다. 실제
비교 계산이 없으므로 DB가 필요 없다 — 다른 테스트처럼 게이팅하지 않는다.
"""


def _valid_payload(**overrides):
    payload = {
        "energy_source": "gas",
        "usage_period": "2026-08",
        "usage_amount": 220,
        "unit": "m3",
        "baseline_total_heat_loss_kwh": 1352.5,
    }
    payload.update(overrides)
    return payload


def test_compare_returns_disclaimer_and_no_result(client):
    response = client.post("/api/v1/bills/compare", json=_valid_payload())

    assert response.status_code == 200
    body = response.json()
    assert body["comparison_result"] is None
    assert "참고용" in body["comparison_note"]
    assert "보정에는 사용되지 않았습니다" in body["comparison_note"]


def test_missing_required_field_returns_422(client):
    payload = _valid_payload()
    del payload["usage_amount"]

    response = client.post("/api/v1/bills/compare", json=payload)

    assert response.status_code == 422
