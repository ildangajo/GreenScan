import { getSessionToken } from "./auth";
import { ApiError, apiRequest } from "./http";

export interface DiagnosisSummary {
  diagnosis_id: string;
  building_type_key: string;
  region_id: string;
  created_at: string;
}

export interface DiagnosisListResponse {
  diagnoses: DiagnosisSummary[];
}

export async function getMyDiagnoses(): Promise<DiagnosisListResponse> {
  const token = getSessionToken();
  if (!token) {
    throw new ApiError("로그인이 필요합니다.", 401, "AUTH_REQUIRED");
  }

  return apiRequest<DiagnosisListResponse>("/api/v1/diagnoses", {
    headers: { Authorization: `Bearer ${token}` },
  });
}
