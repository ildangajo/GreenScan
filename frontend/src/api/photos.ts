import { apiRequest } from "./http";

export type PhotoCategory = "window" | "wall";
export type AssessmentStatus = "completed" | "unassessable" | "failed";
export type PhotoQuality = "usable" | "retake_required" | "unknown";
export type WindowTypeCandidate = "single" | "double" | "triple" | "unknown" | "not_applicable";
export type VisibleAnomalyCandidate = "suspected" | "none_observed" | "unassessable" | "not_applicable";
export type ComponentType = "window" | "wall" | "unknown";

export interface PhotoAnalysisResponse {
  assessment_status: AssessmentStatus;
  photo_quality: PhotoQuality;
  component_type: ComponentType;
  window_type_candidate: WindowTypeCandidate;
  visible_anomaly_candidate: VisibleAnomalyCandidate;
  needs_user_confirmation: boolean;
  reason_summary: string;
  model_version: string;
}

/**
 * backend/app/api/routes/analysis.py — 로그인 불필요, 사진은 서버에 저장되지
 * 않고 분석 후 즉시 폐기된다. 10MB 초과/지원하지 않는 형식/손상된 파일은
 * 400(PHOTO_TOO_LARGE / PHOTO_INVALID_FORMAT / PHOTO_CORRUPTED)로 온다 —
 * ApiError.code로 구분해서 보여주면 된다.
 */
export async function analyzePhoto(category: PhotoCategory, file: File): Promise<PhotoAnalysisResponse> {
  const form = new FormData();
  form.append("category", category);
  form.append("image", file);
  // Content-Type을 직접 지정하지 않는다 — FormData를 fetch에 넘기면 브라우저가
  // boundary가 포함된 multipart/form-data 헤더를 자동으로 붙인다.
  return apiRequest<PhotoAnalysisResponse>("/api/v1/photos/analyze", {
    method: "POST",
    body: form,
  });
}
