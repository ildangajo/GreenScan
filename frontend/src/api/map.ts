import { getSessionToken } from "./auth";
import { ApiError, apiRequest } from "./http";

export interface GeocodeResponse {
  region_id: string;
  hdd_lookup_key: string;
  latitude: number;
  longitude: number;
  road_address: string | null;
}

/**
 * PRD v8.1: 지도 검색은 서울만 지원한다. 서울 밖 주소는 좌표는 구해지더라도
 * UNSUPPORTED_REGION으로 처리된다(api-spec.md 2.1) — ApiError.code로 구분해서
 * 호출부에서 안내 문구를 보여주면 된다. 로그인이 필요한 엔드포인트다
 * (backend/app/api/deps.py get_current_session).
 */
export async function geocodeAddress(address: string): Promise<GeocodeResponse> {
  const token = getSessionToken();
  if (!token) throw new ApiError("로그인이 필요합니다.", 401, "AUTH_REQUIRED");

  return apiRequest<GeocodeResponse>(`/api/v1/map/geocode?address=${encodeURIComponent(address)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}
