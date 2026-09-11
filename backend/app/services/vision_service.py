import base64
import json
import logging

from openai import APIError, APITimeoutError, OpenAI
from pydantic import ValidationError
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from app.core.config import settings
from app.schemas.vision import (
    AssessmentStatus,
    ComponentType,
    PhotoCategory,
    PhotoQuality,
    VisibleAnomalyCandidate,
    VisionAnalysisResult,
    WindowTypeCandidate,
)

logger = logging.getLogger(__name__)

_client = OpenAI(api_key=settings.openai_api_key)

# PRD 6.2: AI는 후보 분류기일 뿐이다. 실제 U값, Low-E, 단열재 상태, 구조 안전성,
# 누수 원인을 확정하지 않는다. 모든 결과는 사용자 확인이 필요하다.
_SYSTEM_PROMPT = """\
너는 주택 진단 보조 도구의 사진 분류기다. 창호 또는 벽체 사진 한 장을 보고 후보값만 제시한다.

역할 경계:
- 너는 실제 측정 도구가 아니다. 길이, 면적, 정확한 U값을 추정하지 않는다.
- 창호 유형(단창/복층창/삼중창)은 후보일 뿐이며 최종 확정이 아니다.
- 벽체 사진에서는 균열, 누수 흔적 등 이상 흔적의 "가능성"만 후보로 제시한다.
  실제 구조 안전성, 누수 원인, 단열재 유무를 진단하지 않는다.
- 사진이 어둡거나, 반사가 심하거나, 너무 멀리서 찍혔으면 photo_quality를
  retake_required로 표시한다.
- 판단이 애매하면 unknown/unassessable을 적극적으로 사용한다. 추측으로 값을
  채우지 않는다.

반드시 주어진 JSON 스키마 형식으로만 응답한다.
"""

_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "assessment_status": {"type": "string", "enum": [e.value for e in AssessmentStatus]},
        "photo_quality": {"type": "string", "enum": [e.value for e in PhotoQuality]},
        "component_type": {"type": "string", "enum": [e.value for e in ComponentType]},
        "window_type_candidate": {"type": "string", "enum": [e.value for e in WindowTypeCandidate]},
        "visible_anomaly_candidate": {"type": "string", "enum": [e.value for e in VisibleAnomalyCandidate]},
        "reason_summary": {"type": "string"},
    },
    "required": [
        "assessment_status",
        "photo_quality",
        "component_type",
        "window_type_candidate",
        "visible_anomaly_candidate",
        "reason_summary",
    ],
    "additionalProperties": False,
}


def _fallback_result(status: AssessmentStatus, reason: str) -> VisionAnalysisResult:
    return VisionAnalysisResult(
        assessment_status=status,
        photo_quality=PhotoQuality.unknown,
        component_type=ComponentType.unknown,
        window_type_candidate=WindowTypeCandidate.unknown,
        visible_anomaly_candidate=VisibleAnomalyCandidate.unassessable,
        needs_user_confirmation=True,
        reason_summary=reason,
    )


@retry(
    reraise=True,
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    retry=retry_if_exception_type((APITimeoutError,)),
)
def _call_vision_api(category: PhotoCategory, image_bytes: bytes, content_type: str) -> str:
    """OpenAI Vision API를 일회성으로 호출한다. 이미지는 이 함수 스코프 밖으로 유출되지 않는다."""
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    data_url = f"data:{content_type};base64,{encoded}"

    response = _client.chat.completions.create(
        model=settings.vision_model,
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": f"사진 카테고리: {category.value}"},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {"name": "vision_analysis_result", "schema": _RESPONSE_SCHEMA, "strict": True},
        },
        timeout=20,
    )
    return response.choices[0].message.content


def analyze_photo(category: PhotoCategory, image_bytes: bytes, content_type: str) -> VisionAnalysisResult:
    """사진 1장을 분석해 구조화된 후보값을 반환한다.

    Vision API 실패, 타임아웃, 스키마 위반은 예외를 던지지 않고 assessment_status=failed로
    반환한다. AI 실패가 전체 진단 실패로 이어지면 안 된다 (PRD 8.2).
    """
    try:
        raw_content = _call_vision_api(category, image_bytes, content_type)
    except (APITimeoutError, APIError) as exc:
        logger.warning("vision api call failed: %s", exc)
        return _fallback_result(AssessmentStatus.failed, "AI 분석에 실패했습니다. 수동으로 선택해주세요.")

    try:
        parsed = json.loads(raw_content)
        result = VisionAnalysisResult.model_validate(parsed)
    except (json.JSONDecodeError, ValidationError) as exc:
        logger.warning("vision api response schema violation: %s", exc)
        return _fallback_result(AssessmentStatus.failed, "AI 응답을 해석할 수 없습니다. 수동으로 선택해주세요.")

    # needs_user_confirmation은 어떤 경우에도 true로 강제한다 (PRD 6.3).
    result.needs_user_confirmation = True
    return result
