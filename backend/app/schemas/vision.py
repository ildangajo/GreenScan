from enum import Enum

from pydantic import BaseModel, Field


class PhotoCategory(str, Enum):
    window = "window"
    wall = "wall"


class AssessmentStatus(str, Enum):
    completed = "completed"
    unassessable = "unassessable"
    failed = "failed"


class PhotoQuality(str, Enum):
    usable = "usable"
    retake_required = "retake_required"
    unknown = "unknown"


class ComponentType(str, Enum):
    window = "window"
    wall = "wall"
    unknown = "unknown"


class WindowTypeCandidate(str, Enum):
    single = "single"
    double = "double"
    triple = "triple"
    unknown = "unknown"
    not_applicable = "not_applicable"


class VisibleAnomalyCandidate(str, Enum):
    suspected = "suspected"
    none_observed = "none_observed"
    unassessable = "unassessable"
    not_applicable = "not_applicable"


class VisionAnalysisResult(BaseModel):
    """Vision API 원시 구조화 응답. 계산에 직접 쓰지 않는다 — 후보값일 뿐이다."""

    assessment_status: AssessmentStatus
    photo_quality: PhotoQuality
    component_type: ComponentType
    window_type_candidate: WindowTypeCandidate
    visible_anomaly_candidate: VisibleAnomalyCandidate
    needs_user_confirmation: bool = True
    reason_summary: str = Field(default="", max_length=500)


class PhotoAnalysisResponse(VisionAnalysisResult):
    model_version: str
