import { getSessionToken } from "./auth";
import { ApiError, apiRequest } from "./http";

export interface FavoriteItem {
  favorite_id: string;
  diagnosis_id: string;
  created_at: string;
}

export interface FavoriteListResponse {
  favorites: FavoriteItem[];
}

function authHeader(): HeadersInit {
  const token = getSessionToken();
  if (!token) throw new ApiError("로그인이 필요합니다.", 401, "AUTH_REQUIRED");
  return { Authorization: `Bearer ${token}` };
}

/** "저장" 탭(SavedPage)이 최종적으로 이걸 쓰게 된다. PRD v8.1 2.2절: 저장은
 * 진단 결과 1건 단위의 단순 즐겨찾기 토글이다. */
export async function listFavorites(): Promise<FavoriteItem[]> {
  const res = await apiRequest<FavoriteListResponse>("/api/v1/favorites", { headers: authHeader() });
  return res.favorites;
}

export async function createFavorite(diagnosisId: string): Promise<FavoriteItem> {
  return apiRequest<FavoriteItem>("/api/v1/favorites", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...authHeader() },
    body: JSON.stringify({ diagnosis_id: diagnosisId }),
  });
}

/** SavedPage의 하트 버튼이 "저장 취소" 상태가 될 때 이걸 호출하면 된다(현재는 TODO로 UI만 토글 중) */
export async function deleteFavorite(favoriteId: string): Promise<void> {
  await apiRequest<void>(`/api/v1/favorites/${favoriteId}`, {
    method: "DELETE",
    headers: authHeader(),
  });
}
