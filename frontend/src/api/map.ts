import { apiFetch } from "./client";
import type { GeocodeResponse } from "./types";

/**
 * PRD v8.1: 지도 검색은 서울만 지원한다. 서울 밖 주소는 좌표는 구해지더라도
 * UNSUPPORTED_REGION으로 처리된다(api-spec.md 2.1) — 백엔드가 4xx로 던지면
 * ApiError로 올라오니 호출부에서 status/body로 구분해서 안내 문구를 보여주면 된다.
 *
 * OpenAPI 스키마상 authorization 헤더가 optional로 보이지만, 실제로는
 * 로그인 없이 호출하면 401 UNAUTHORIZED가 온다(2026-09-11 라이브 서버에서
 * 직접 확인). 로그인 플로우(feat/fe-auth-login 브랜치)가 이 브랜치에 아직
 * 없어서, 세션 토큰이 없으면 이 함수는 항상 401로 실패한다 — 로그인 화면이
 * 합류하면 자연스럽게 동작한다.
 */
export async function geocodeAddress(address: string): Promise<GeocodeResponse> {
  return apiFetch<GeocodeResponse>(`/api/v1/map/geocode?address=${encodeURIComponent(address)}`);
}
