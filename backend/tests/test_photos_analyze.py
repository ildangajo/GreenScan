"""PRD 12장 통합 테스트 케이스 중 Vision(BE-B) 관련 시나리오.

#4 사진 품질 부족: 재촬영 필요가 반환되어도 사용자가 수동 선택 후 결과까지 갈 수 있음
#5 Vision 장애: API 시간초과나 스키마 오류에도 AI 실패가 전체 진단 실패가 되지 않음
#9 원본 폐기: 사진 분석 API 처리 후 서버 영구 저장소에 원본 사진이 남지 않음

실제 OpenAI API는 호출하지 않는다. app.services.vision_service._call_vision_api만
모킹해서, 이 레이어 위쪽(엔드포인트 검증, 실패 처리, 폐기 정책)이 계약대로
동작하는지만 검증한다.
"""

import builtins
import json
from unittest.mock import patch

from openai import APITimeoutError


def _post_photo(client, image_bytes: bytes, category: str = "window"):
    return client.post(
        "/api/v1/photos/analyze",
        data={"category": category},
        files={"image": ("test.jpg", image_bytes, "image/jpeg")},
    )


def test_completed_analysis_still_requires_user_confirmation(client, valid_jpeg_bytes):
    mock_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "window",
            "window_type_candidate": "double",
            "visible_anomaly_candidate": "not_applicable",
            "reason_summary": "창틀 이중 프레임이 보입니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, valid_jpeg_bytes)

    assert response.status_code == 200
    body = response.json()
    assert body["assessment_status"] == "completed"
    # PRD 6.3: completed여도 계산 전에는 반드시 사용자 확정이 필요하다.
    assert body["needs_user_confirmation"] is True


def test_photo_quality_retake_required_does_not_block_response(client, valid_jpeg_bytes):
    """시나리오 #4: 재촬영 필요가 반환돼도 200으로 응답해 사용자가 수동 선택으로 넘어갈 수 있다."""
    mock_response = json.dumps(
        {
            "assessment_status": "unassessable",
            "photo_quality": "retake_required",
            "component_type": "window",
            "window_type_candidate": "unknown",
            "visible_anomaly_candidate": "not_applicable",
            "reason_summary": "역광으로 창틀이 잘 보이지 않습니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, valid_jpeg_bytes)

    assert response.status_code == 200
    body = response.json()
    assert body["photo_quality"] == "retake_required"
    assert body["assessment_status"] == "unassessable"
    assert body["needs_user_confirmation"] is True


def test_vision_api_timeout_falls_back_to_failed(client, valid_jpeg_bytes):
    """시나리오 #5-1: Vision API 타임아웃이 전체 요청 실패(5xx)로 이어지지 않는다."""
    with patch(
        "app.services.vision_service._call_vision_api",
        side_effect=APITimeoutError(request=None),
    ):
        response = _post_photo(client, valid_jpeg_bytes)

    assert response.status_code == 200
    body = response.json()
    assert body["assessment_status"] == "failed"
    assert body["needs_user_confirmation"] is True


def test_vision_api_schema_violation_falls_back_to_failed(client, valid_jpeg_bytes):
    """시나리오 #5-2: 스키마를 어긴 응답도 500이 아니라 failed로 처리된다."""
    with patch(
        "app.services.vision_service._call_vision_api",
        return_value=json.dumps({"unexpected": "shape"}),
    ):
        response = _post_photo(client, valid_jpeg_bytes)

    assert response.status_code == 200
    assert response.json()["assessment_status"] == "failed"


def test_vision_api_non_json_response_falls_back_to_failed(client, valid_jpeg_bytes):
    with patch(
        "app.services.vision_service._call_vision_api",
        return_value="not even json",
    ):
        response = _post_photo(client, valid_jpeg_bytes)

    assert response.status_code == 200
    assert response.json()["assessment_status"] == "failed"


def test_wall_category_forces_window_type_not_applicable(client, valid_jpeg_bytes):
    """모델이 프롬프트를 어기고 wall 사진에 window_type_candidate를 채워도 서버가 되돌린다."""
    mock_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "wall",
            "window_type_candidate": "double",  # 모델이 잘못 채운 값
            "visible_anomaly_candidate": "suspected",
            "reason_summary": "벽면에 균열로 추정되는 흔적이 보입니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, valid_jpeg_bytes, category="wall")

    assert response.status_code == 200
    assert response.json()["window_type_candidate"] == "not_applicable"


def test_window_category_forces_anomaly_not_applicable(client, valid_jpeg_bytes):
    """모델이 프롬프트를 어기고 window 사진에 visible_anomaly_candidate를 채워도 서버가 되돌린다."""
    mock_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "window",
            "window_type_candidate": "single",
            "visible_anomaly_candidate": "suspected",  # 모델이 잘못 채운 값
            "reason_summary": "단창으로 보입니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, valid_jpeg_bytes, category="window")

    assert response.status_code == 200
    assert response.json()["visible_anomaly_candidate"] == "not_applicable"


def test_oversized_photo_returns_400(client):
    """api-spec.md 0.1: 사진 1장 최대 10MB 확정 — 초과분은 즉시 거부한다."""
    from app.api.routes.analysis import _MAX_FILE_SIZE_BYTES

    oversized_bytes = b"\xff" * (_MAX_FILE_SIZE_BYTES + 1)

    response = _post_photo(client, oversized_bytes)

    assert response.status_code == 400
    body = response.json()["detail"]
    assert body["error_code"] == "PHOTO_TOO_LARGE"
    assert body["detail"]["max_size_bytes"] == _MAX_FILE_SIZE_BYTES


def test_photo_at_size_limit_passes_size_check(client, valid_jpeg_bytes):
    """정확히 상한 크기까지는 PHOTO_TOO_LARGE로 막히면 안 되고 분석까지 진행된다."""
    from app.api.routes.analysis import _MAX_FILE_SIZE_BYTES

    padding = b"\x00" * (_MAX_FILE_SIZE_BYTES - len(valid_jpeg_bytes))
    at_limit_bytes = valid_jpeg_bytes + padding
    assert len(at_limit_bytes) == _MAX_FILE_SIZE_BYTES

    mock_response = json.dumps(
        {
            "assessment_status": "unassessable",
            "photo_quality": "unknown",
            "component_type": "window",
            "window_type_candidate": "unknown",
            "visible_anomaly_candidate": "not_applicable",
            "reason_summary": "이미지 뒷부분이 손상되어 판단이 어렵습니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, at_limit_bytes)

    # 용량 상한 자체에는 걸리지 않고 정상적으로 분석 단계까지 도달해야 한다.
    assert response.status_code == 200


def test_invalid_category_returns_400(client, valid_jpeg_bytes):
    response = _post_photo(client, valid_jpeg_bytes, category="roof")

    assert response.status_code == 400
    assert response.json()["detail"]["error_code"] == "PHOTO_CATEGORY_INVALID"


def test_corrupted_image_returns_400(client):
    response = _post_photo(client, b"not an image", category="wall")

    assert response.status_code == 400
    assert response.json()["detail"]["error_code"] == "PHOTO_CORRUPTED"


def test_unsupported_content_type_returns_400(client, valid_jpeg_bytes):
    response = client.post(
        "/api/v1/photos/analyze",
        data={"category": "window"},
        files={"image": ("test.gif", valid_jpeg_bytes, "image/gif")},
    )

    assert response.status_code == 400
    assert response.json()["detail"]["error_code"] == "PHOTO_INVALID_FORMAT"


def test_original_photo_is_never_written_to_disk(client, valid_jpeg_bytes, monkeypatch):
    """시나리오 #9: 원본 사진을 어떤 파일에도 쓰지 않는다.

    실제 파일시스템 접근 없이도(모킹된 Vision 호출 하나만으로) 요청을 끝낼 수 있으므로,
    이 요청 처리 동안 쓰기 모드로 열린 파일이 하나도 없어야 한다.
    """
    write_calls: list[tuple[str, str]] = []
    original_open = builtins.open

    def spy_open(file, mode="r", *args, **kwargs):
        if any(flag in mode for flag in ("w", "a", "x")):
            write_calls.append((str(file), mode))
        return original_open(file, mode, *args, **kwargs)

    monkeypatch.setattr(builtins, "open", spy_open)

    mock_response = json.dumps(
        {
            "assessment_status": "completed",
            "photo_quality": "usable",
            "component_type": "wall",
            "window_type_candidate": "not_applicable",
            "visible_anomaly_candidate": "none_observed",
            "reason_summary": "표면에 뚜렷한 이상 흔적이 보이지 않습니다.",
        }
    )
    with patch("app.services.vision_service._call_vision_api", return_value=mock_response):
        response = _post_photo(client, valid_jpeg_bytes, category="wall")

    assert response.status_code == 200
    assert write_calls == []
