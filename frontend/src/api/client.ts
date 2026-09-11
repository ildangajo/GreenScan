/**
 * 공용 fetch 래퍼. 엔드포인트별 함수(favorites.ts, diagnoses.ts 등)는
 * 전부 이걸 거쳐서 호출한다.
 *
 * - 베이스 URL은 frontend/.env의 VITE_API_BASE_URL을 쓴다(README/백엔드 전달
 *   문서 기준 로컬 개발 주소는 http://3.38.160.29:8000). .env가 없으면
 *   http://localhost:8000로 fallback.
 * - 로그인 세션 토큰은 localStorage에 저장하고 매 요청에 Authorization 헤더로
 *   실어 보낸다(백엔드가 "authorization" 헤더 하나로만 인증하는 구조,
 *   OpenAPI 스키마 기준 Bearer 프리픽스 여부는 문서화돼 있지 않아 토큰
 *   원문을 그대로 보낸다 — 백엔드가 "Bearer " 프리픽스를 요구하면 여기만
 *   고치면 된다).
 */

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";
const TOKEN_STORAGE_KEY = "greenscan.session_token";

export class ApiError extends Error {
  status: number;
  body: unknown;

  constructor(status: number, body: unknown, message?: string) {
    super(message ?? `API 요청 실패 (status ${status})`);
    this.name = "ApiError";
    this.status = status;
    this.body = body;
  }
}

export function getSessionToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_STORAGE_KEY);
  } catch {
    // localStorage 접근이 막힌 환경(시크릿 모드 등)에서도 앱이 죽지 않게
    return null;
  }
}

export function setSessionToken(token: string | null) {
  try {
    if (token) localStorage.setItem(TOKEN_STORAGE_KEY, token);
    else localStorage.removeItem(TOKEN_STORAGE_KEY);
  } catch {
    // no-op
  }
}

interface RequestOptions {
  method?: "GET" | "POST" | "DELETE" | "PATCH" | "PUT";
  body?: unknown;
  /** 로그인 자체 요청처럼 토큰을 붙이면 안 되는 경우 false로 */
  auth?: boolean;
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, auth = true } = options;

  const headers: Record<string, string> = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (auth) {
    const token = getSessionToken();
    if (token) headers["authorization"] = token;
  }

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  // 204 No Content 등 바디 없는 응답 처리
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;

  if (!res.ok) {
    throw new ApiError(res.status, data);
  }

  return data as T;
}
