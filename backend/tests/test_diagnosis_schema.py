"""api-spec.md 2.4 요청 검증 규칙 테스트 (BE-A 입력 검증 책임).

실제 /diagnoses/calculate 엔드포인트는 아직 없다(BE-C 계산 엔진 미구현).
이 테스트는 그 전에 먼저 확정한 입력 계약과 검증 규칙만 검증한다.
"""

import pytest
from pydantic import ValidationError

from app.schemas.diagnosis import CalculateRequest, WallNetAreaInvalidError, check_wall_net_area


def _valid_payload(**overrides):
    payload = {
        "building": {
            "building_type": "apartment",
            "representative_space_type": "living_room",
            "construction_year_range": "1995-2005",
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
            "insulation_status": "none",
            "visible_anomaly_confirmed": "none_observed",
            "input_source": "manual",
        },
        "location": {"region_id": "seoul"},
        "bill": None,
    }
    payload.update(overrides)
    return payload


def test_valid_payload_parses_and_computes_net_wall_area():
    request = CalculateRequest.model_validate(_valid_payload())

    assert request.wall_net_area_m2 == pytest.approx(12.0 - 3.6)
    assert check_wall_net_area(request) == pytest.approx(8.4)


def test_wall_net_area_zero_or_negative_is_rejected():
    request = CalculateRequest.model_validate(
        _valid_payload(wall={
            "exterior_total_area_m2": 3.6,
            "insulation_status": "none",
            "visible_anomaly_confirmed": "none_observed",
            "input_source": "manual",
        })
    )

    with pytest.raises(WallNetAreaInvalidError):
        check_wall_net_area(request)


def test_window_type_candidate_unknown_is_rejected():
    """PRD 6.3: AI 후보의 unknown은 계산 입력으로 올 수 없다 — 3개 중 반드시 확정."""
    with pytest.raises(ValidationError):
        CalculateRequest.model_validate(
            _valid_payload(window={
                "total_area_m2": 3.6,
                "window_type": "unknown",
                "low_e": "unknown",
                "input_source": "user_corrected",
            })
        )


def test_lidar_input_source_is_rejected():
    """api-spec.md 2.4: lidar는 예약값일 뿐 이번 MVP API가 받지 않는다."""
    with pytest.raises(ValidationError):
        CalculateRequest.model_validate(
            _valid_payload(space={
                "width_m": 4.2,
                "depth_m": 3.5,
                "height_m": 2.4,
                "floor_area_m2": 14.7,
                "input_source": "lidar",
            })
        )


def test_non_positive_dimensions_are_rejected():
    with pytest.raises(ValidationError):
        CalculateRequest.model_validate(
            _valid_payload(space={
                "width_m": 0,
                "depth_m": 3.5,
                "height_m": 2.4,
                "floor_area_m2": 14.7,
                "input_source": "manual",
            })
        )
