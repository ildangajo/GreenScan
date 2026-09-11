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
    <main className="mypage">
      <header className="mypage__header">
        <h1>마이페이지</h1>
      </header>

      <section className="profile-card" aria-labelledby="profile-heading">
        <h2 id="profile-heading">{getDisplayName()}님</h2>
        <p>GreenScan에서 우리 집의 변화를 확인해보세요.</p>
      </section>

      <section className="diagnosis-history" aria-labelledby="history-heading">
        <h2 id="history-heading">최근 진단 기록</h2>

        {isLoading && <p>진단 기록을 불러오는 중...</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
        {!isLoading && !error && diagnoses.length === 0 && <p>저장된 진단 기록이 없습니다.</p>}

        {!isLoading && diagnoses.length > 0 && (
          <ul className="diagnosis-list">
            {diagnoses.map((diagnosis) => (
              <li className="diagnosis-card" key={diagnosis.diagnosis_id}>
                <button
                  type="button"
                  onClick={() => navigate(`/diagnoses/${diagnosis.diagnosis_id}`)}
                >
                  <strong>{diagnosis.building_type_key}</strong>
                  <span>{diagnosis.region_id}</span>
                  <time dateTime={diagnosis.created_at}>
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

      <section className="account-actions" aria-label="계정 설정">
        <button type="button" onClick={handleLogout} disabled={isLoggingOut}>
          {isLoggingOut ? "로그아웃 중..." : "로그아웃"}
        </button>
      </section>

      {/* 다른 탭 화면(홈/저장/추천)과 동일한 공용 하단 탭바 — 원래 이 화면엔 없었어서 병합하며 추가함 */}
      <BottomNav active="mypage" />
    </main>
  );
}
