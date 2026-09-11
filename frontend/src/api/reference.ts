import { apiFetch } from "./client";
import type { ReferenceOptionsResponse, RegionsResponse } from "./types";

/** 건물유형/공간유형/창호/연도 등 드롭다운 옵션. AI 분석하기·space-input 화면이 이걸로 옵션을 채우게 된다 */
export async function getReferenceOptions(): Promise<ReferenceOptionsResponse> {
  return apiFetch<ReferenceOptionsResponse>("/api/v1/reference/options", { auth: false });
}

export async function getRegions(): Promise<RegionsResponse> {
  return apiFetch<RegionsResponse>("/api/v1/regions", { auth: false });
}
