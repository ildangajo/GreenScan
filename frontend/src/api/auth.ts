import { apiFetch, setSessionToken } from "./client";
import type { LoginRequest, LoginResponse } from "./types";

/** DB에 시드된 계정으로만 로그인 가능 — 자체 회원가입 플로우는 없음(PRD v8.1). */
export async function login(payload: LoginRequest): Promise<LoginResponse> {
  const res = await apiFetch<LoginResponse>("/api/v1/auth/login", {
    method: "POST",
    body: payload,
    auth: false,
  });
  setSessionToken(res.session_token);
  return res;
}

export async function logout(): Promise<void> {
  try {
    await apiFetch<void>("/api/v1/auth/logout", { method: "POST" });
  } finally {
    setSessionToken(null);
  }
}
