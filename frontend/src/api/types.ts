/**
 * 백엔드 OpenAPI 스키마(http://3.38.160.29:8000/openapi.json, 2026-09-11 기준)를
 * 그대로 옮긴 타입. 서버 쪽 스키마가 바뀌면 이 파일도 같이 갱신해야 한다 —
 * 자동 생성 스크립트는 아직 없다(수동 동기화).
 *
 * calculation_result / confirmed_input은 백엔드에서 `object`(자유 형식)로만
 * 정의돼 있어 내부 필드 계약이 아직 없다. 실제 필드가 확정되면 여기 타입을
 * 채우고, 화면 쪽 목업 데이터(썸네일/절감률 등)를 이걸로 교체하면 된다.
 */

export interface OptionItem {
  value: string;
  label: string;
}

export interface BuildingTypeOption extends OptionItem {
  u_value_reference_group: string;
}

export interface ConstructionYearRangeOption extends OptionItem {
  min_year: number | null;
  max_year: number | null;
}

export interface ReferenceOptionsResponse {
  options_version: string;
  building_types: BuildingTypeOption[];
  representative_space_types: OptionItem[];
  window_type_options: OptionItem[];
  low_e_options: OptionItem[];
  construction_year_ranges: ConstructionYearRangeOption[];
  wall_insulation_status_options: OptionItem[];
  wall_visible_anomaly_confirm_options: OptionItem[];
}

export interface RegionItem {
  region_id: string;
  display_name: string;
  hdd_lookup_key: string;
  climate_zone: string;
  climate_zone_description: string;
  supported: boolean;
}

export interface RegionsResponse {
  data_version: string;
  regions: RegionItem[];
}

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

export interface FavoriteItem {
  favorite_id: string;
  diagnosis_id: string;
  created_at: string;
}

export interface FavoriteListResponse {
  favorites: FavoriteItem[];
}

export interface FavoriteCreateRequest {
  diagnosis_id: string;
}

export interface LoginRequest {
  login_id: string;
  password: string;
}

export interface LoginResponse {
  session_token: string;
  expires_at: string;
  display_name: string | null;
}

export interface GeocodeResponse {
  region_id: string;
  hdd_lookup_key: string;
  latitude: number;
  longitude: number;
  road_address: string | null;
}
