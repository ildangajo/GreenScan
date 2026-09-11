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

// ---- POST /api/v1/diagnoses/calculate 요청/응답 — backend/app/schemas/{diagnosis,calculation}.py 그대로 ----

export type InputSource = "manual" | "user_corrected";

export interface BuildingInput {
  building_type: string;
  representative_space_type: string;
  construction_year_range: string;
}

export interface SpaceInput {
  width_m: number;
  depth_m: number;
  height_m: number;
  floor_area_m2: number;
  input_source: InputSource;
}

export interface WindowInput {
  total_area_m2: number;
  window_type: string;
  low_e: string;
  input_source: InputSource;
}

export interface WallInput {
  exterior_total_area_m2: number;
  insulation_status: string;
  visible_anomaly_confirmed: string;
  input_source: InputSource;
}

export interface LocationInput {
  region_id: string;
}

export interface BillInput {
  energy_source: string;
  usage_period: string;
  usage_amount: number;
  unit: string;
}

export interface CalculateRequest {
  building: BuildingInput;
  space: SpaceInput;
  window: WindowInput;
  wall: WallInput;
  location: LocationInput;
  bill?: BillInput | null;
}

export interface ReferenceDataVersion {
  current_u_value_window: string;
  current_u_value_wall: string;
  target_u_value: string;
  hdd: string;
}

export interface BaselineResult {
  window_heat_loss_kwh: number;
  wall_heat_loss_kwh: number;
  total_heat_loss_kwh: number;
}

export interface ScenarioResult {
  scenario_id: string;
  name: string;
  changed_components: string[];
  annual_reduction_kwh: number;
  reduction_rate: number;
  priority: number;
}

export interface WallAnomalyNotice {
  status: string;
  message: string;
}

export interface CalculateResponse {
  calculation_version: string;
  reference_data_version: ReferenceDataVersion;
  baseline: BaselineResult;
  scenarios: ScenarioResult[];
  wall_anomaly_notice: WallAnomalyNotice;
  unit_scope_disclaimer: string;
  bill_comparison: null;
}

/**
 * PRD 9.1: 계산 API는 로그인 여부와 무관하게 동작한다(인증 헤더 불필요).
 * 결과를 계정에 저장하려면 별도로 createDiagnosis()를 호출해야 한다.
 * 실패 시 백엔드가 던지는 error_code: WALL_NET_AREA_INVALID(422),
 * UNSUPPORTED_REGION(400), INVALID_ENUM_VALUE(400), REFERENCE_DATA_MISSING(422)
 * — ApiError.code로 구분해서 화면별 안내 문구를 다르게 보여주면 된다.
 */
export async function calculateDiagnosis(payload: CalculateRequest): Promise<CalculateResponse> {
  return apiRequest<CalculateResponse>("/api/v1/diagnoses/calculate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

function authHeader(): HeadersInit {
  const token = getSessionToken();
  if (!token) throw new ApiError("로그인이 필요합니다.", 401, "AUTH_REQUIRED");
  return { Authorization: `Bearer ${token}` };
}

/** 마이페이지(MyPage) 진단 이력이 쓰는 이름. 홈 "최근 분석한 건물"도 결국 같은 데이터라 listDiagnoses()로 재사용한다. */
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
