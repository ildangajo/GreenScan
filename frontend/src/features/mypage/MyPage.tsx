import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import { getDisplayName, getSessionToken, logout } from "../../api/auth";
import { getMyDiagnoses, type DiagnosisSummary } from "../../api/diagnoses";
import { ApiError } from "../../api/http";
import BottomNav from "../../components/ui/BottomNav";

export default function MyPage() {
  const navigate = useNavigate();
  const [diagnoses, setDiagnoses] = useState<DiagnosisSummary[]>([]);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  useEffect(() => {
    if (!getSessionToken()) {
      navigate("/login", { replace: true });
      return;
    }

    void getMyDiagnoses()
      .then((result) => setDiagnoses(result.diagnoses))
      .catch((caught) => {
        if (caught instanceof ApiError && caught.status === 401) {
          navigate("/login", { replace: true });
          return;
        }
        setError(caught instanceof Error ? caught.message : "진단 기록을 불러오지 못했습니다.");
      })
      .finally(() => setIsLoading(false));
  }, [navigate]);

  async function handleLogout() {
    setIsLoggingOut(true);
    setError("");
    try {
      await logout();
      navigate("/login", { replace: true });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "로그아웃에 실패했습니다.");
      setIsLoggingOut(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col bg-neutral-50 px-6 pb-28 pt-10">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-neutral-900">마이페이지</h1>
      </header>

      <section
        className="mb-6 rounded-2xl bg-white px-5 py-6 shadow-sm"
        aria-labelledby="profile-heading"
      >
        <h2 id="profile-heading" className="text-lg font-bold text-neutral-900">
          {getDisplayName()}님
        </h2>
        <p className="mt-1 text-sm text-neutral-500">GreenScan에서 이 집의 변화를 확인해보세요.</p>
      </section>

      <section className="mb-6" aria-labelledby="history-heading">
        <h2 id="history-heading" className="mb-3 text-base font-bold text-neutral-900">
          최근 진단 기록
        </h2>

        {isLoading && <p className="text-sm text-neutral-500">진단 기록을 불러오는 중...</p>}
        {error && (
          <p className="text-sm font-medium text-red-500" role="alert">
            {error}
          </p>
        )}
        {!isLoading && !error && diagnoses.length === 0 && (
          <p className="text-sm text-neutral-500">저장된 진단 기록이 없습니다.</p>
        )}

        {!isLoading && diagnoses.length > 0 && (
          <ul className="flex flex-col gap-3">
            {diagnoses.map((diagnosis) => (
              <li
                className="rounded-2xl bg-white shadow-sm"
                key={diagnosis.diagnosis_id}
              >
                <button
                  type="button"
                  onClick={() => navigate(`/diagnoses/${diagnosis.diagnosis_id}`)}
                  className="flex w-full flex-col gap-1 px-5 py-4 text-left"
                >
                  <strong className="text-sm font-semibold text-neutral-900">
                    {diagnosis.building_type_key}
                  </strong>
                  <span className="text-sm text-neutral-500">{diagnosis.region_id}</span>
                  <time dateTime={diagnosis.created_at} className="text-xs text-neutral-400">
                    {new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium" }).format(
                      new Date(diagnosis.created_at),
                    )}
                  </time>
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-label="계정 설정">
        <button
          type="button"
          onClick={handleLogout}
          disabled={isLoggingOut}
          className="w-full rounded-xl border border-neutral-200 bg-white py-3.5 text-sm font-semibold text-neutral-700 disabled:opacity-60"
        >
          {isLoggingOut ? "로그아웃 중..." : "로그아웃"}
        </button>
      </section>

      {/* 다른 탭 화면(홈/저장/추천)과 동일한 공용 하단 탭바 — 원래 이 화면엔 없었어서 병합하며 추가함 */}
      <BottomNav active="mypage" />
    </main>
  );
}
