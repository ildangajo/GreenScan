import { apiRequest } from "./http";

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

/** 건물유형/공간유형/창호/연도 등 드롭다운 옵션. 로그인 없이도 조회 가능(공개 API) */
export async function getReferenceOptions(): Promise<ReferenceOptionsResponse> {
  return apiRequest<ReferenceOptionsResponse>("/api/v1/reference/options");
}

export async function getRegions(): Promise<RegionsResponse> {
  return apiRequest<RegionsResponse>("/api/v1/regions");
}
