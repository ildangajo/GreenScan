import { getSessionToken } from "./auth";
import { ApiError, apiRequest } from "./http";

export interface DiagnosisSummary {
  diagnosis_id: string;
  building_type_key: string;
  region_id: string;
  created_at: string;
}

export interface DiagnosisDetail extends DiagnosisSummary {
  confirmed_input: Record<string, unknown>;
  calculation_result: Record<string, unknown>;
  calculation_version: string;
  reference_data_version: string;
}

export interface DiagnosisListResponse {
  diagnoses: DiagnosisSummary[];
}

export interface DiagnosisCreateRequest {
  building_type_key: string;
  region_id: string;
  confirmed_input: Record<string, unknown>;
  calculation_result: Record<string, unknown>;
  calculation_version: string;
  reference_data_version: string;
}

function authHeader(): HeadersInit {
  const token = getSessionToken();
  if (!token) throw new ApiError("로그인이 필요합니다.", 401, "AUTH_REQUIRED");
  return { Authorization: `Bearer ${token}` };
}

/** 마이페이지 진단 이력이 쓰는 이름. 홈 "최근 분석한 건물"도 결국 같은 데이터라 listDiagnoses()로 재사용한다. */
export function getMyDiagnoses(): Promise<DiagnosisListResponse> {
  return apiRequest<DiagnosisListResponse>("/api/v1/diagnoses", { headers: authHeader() });
}

export async function listDiagnoses(): Promise<DiagnosisSummary[]> {
  const res = await getMyDiagnoses();
  return res.diagnoses;
}

export async function getDiagnosis(diagnosisId: string): Promise<DiagnosisDetail> {
  return apiRequest<DiagnosisDetail>(`/api/v1/diagnoses/${diagnosisId}`, { headers: authHeader() });
}

/**
 * 계산이 끝난 결과를 계정에 귀속해 저장한다. 저장 시점(계산 즉시 자동 vs
 * 사용자가 명시적으로 버튼을 누름)은 아직 정책 확정 전이라, 계산 엔진(BE-C)
 * 응답이 정해지면 이 요청 바디를 그대로 채워서 호출하면 된다.
 */
export async function createDiagnosis(payload: DiagnosisCreateRequest): Promise<DiagnosisDetail> {
  return apiRequest<DiagnosisDetail>("/api/v1/diagnoses", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...authHeader() },
    body: JSON.stringify(payload),
  });
}
