import { apiFetch } from "./client";
import type { FavoriteItem, FavoriteListResponse } from "./types";

/** "저장" 탭(SavedPage)이 최종적으로 이걸 쓰게 된다. PRD v8.1 2.2절: 저장은
 * 진단 결과 1건 단위의 단순 즐겨찾기 토글이다. */
export async function listFavorites(): Promise<FavoriteItem[]> {
  const res = await apiFetch<FavoriteListResponse>("/api/v1/favorites");
  return res.favorites;
}

export async function createFavorite(diagnosisId: string): Promise<FavoriteItem> {
  return apiFetch<FavoriteItem>("/api/v1/favorites", {
    method: "POST",
    body: { diagnosis_id: diagnosisId },
  });
}

/** SavedPage의 하트 버튼이 "저장 취소" 상태가 될 때 이걸 호출하면 된다(현재는 TODO로 UI만 토글 중) */
export async function deleteFavorite(favoriteId: string): Promise<void> {
  await apiFetch<void>(`/api/v1/favorites/${favoriteId}`, { method: "DELETE" });
}
