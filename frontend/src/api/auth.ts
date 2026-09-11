import { apiRequest } from "./http";

const SESSION_TOKEN_KEY = "greenscan_session_token";
const DISPLAY_NAME_KEY = "greenscan_display_name";

export interface LoginRequest {
  login_id: string;
  password: string;
}

export interface LoginResponse {
  session_token: string;
  expires_at: string;
  display_name: string | null;
}

export async function login(payload: LoginRequest): Promise<LoginResponse> {
  const result = await apiRequest<LoginResponse>("/api/v1/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  sessionStorage.setItem(SESSION_TOKEN_KEY, result.session_token);
  sessionStorage.setItem(DISPLAY_NAME_KEY, result.display_name ?? "");
  return result;
}

export async function logout(): Promise<void> {
  const token = getSessionToken();
  if (token) {
    await apiRequest<void>("/api/v1/auth/logout", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    });
  }
  clearSession();
}

export function getSessionToken(): string | null {
  return sessionStorage.getItem(SESSION_TOKEN_KEY);
}

export function getDisplayName(): string {
  return sessionStorage.getItem(DISPLAY_NAME_KEY) || "사용자";
}

export function clearSession(): void {
  sessionStorage.removeItem(SESSION_TOKEN_KEY);
  sessionStorage.removeItem(DISPLAY_NAME_KEY);
}
