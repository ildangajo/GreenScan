import { apiFetch } from "./client";
import type { DiagnosisCreateRequest, DiagnosisDetail, DiagnosisListResponse, DiagnosisSummary } from "./types";

/** 홈 "최근 분석한 건물" 목록이 최종적으로 이걸 쓰게 된다 */
export async function listDiagnoses(): Promise<DiagnosisSummary[]> {
  const res = await apiFetch<DiagnosisListResponse>("/api/v1/diagnoses");
  return res.diagnoses;
}

export async function getDiagnosis(diagnosisId: string): Promise<DiagnosisDetail> {
  return apiFetch<DiagnosisDetail>(`/api/v1/diagnoses/${diagnosisId}`);
}

/**
 * 계산이 끝난 결과를 계정에 귀속해 저장한다. 저장 시점(계산 즉시 자동 vs
 * 사용자가 명시적으로 버튼을 누름)은 아직 정책 확정 전이라, 계산 엔진(BE-C)
 * 응답이 정해지면 이 요청 바디를 그대로 채워서 호출하면 된다.
 */
export async function createDiagnosis(payload: DiagnosisCreateRequest): Promise<DiagnosisDetail> {
  return apiFetch<DiagnosisDetail>("/api/v1/diagnoses", { method: "POST", body: payload });
}
