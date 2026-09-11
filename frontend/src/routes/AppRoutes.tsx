import { Route, Routes } from "react-router-dom";
import HomePage from "../features/home/HomePage";
import LoginPage from "../features/auth/LoginPage";
import SignupPage from "../features/auth/SignupPage";
import MyPage from "../features/mypage/MyPage";
import AiDiagnosisStartPage from "../features/ai-diagnosis/AiDiagnosisStartPage";
import RecommendationPage from "../features/recommendation/RecommendationPage";
import SavedPage from "../features/saved/SavedPage";
import BuildingSpaceSelectPage from "../features/space-input/BuildingSpaceSelectPage";
import SpaceInputPage from "../features/space-input/SpaceInputPage";
import PhotoUploadPage from "../features/vision-analysis/PhotoUploadPage";
import AiConfirmPage from "../features/vision-analysis/AiConfirmPage";
import ResultPage from "../features/calculation-result/ResultPage";

/**
 * GreenScan MVP Must 흐름(PRD v7 2.1) 기준 5단계 목업 라우팅 + 홈 화면.
 * 홈 화면은 PRD 원안에는 없고 디자인팀 시안 검토 후 추가된 진입점이다
 * (docs/prd-v7-deviations.md #4 참고).
 * 화면 1(건물유형+대표공간)과 2(치수/면적 입력)는 features/space-input,
 * 화면 3(사진업로드)과 4(AI 후보확인)는 features/vision-analysis,
 * 화면 5(결과)는 features/calculation-result 아래에 둔다.
 *
 * /ai-diagnosis: 홈 히어로 배너 "AI 진단 시작하기"의 진입 화면(주소/연도 입력).
 * 기존 5단계 플로우(/start 이하)는 그 자체로는 주소 입력이 없어 결과 계산에
 * 필요한 region_id를 못 만든다 — /ai-diagnosis에서 주소를 확인해
 * DiagnosisContext에 region_id를 저장한 뒤 /start로 이어지는 구조로 확정했다.
 * /start에 region_id 없이 직접 들어오면 BuildingSpaceSelectPage가 자동으로
 * /ai-diagnosis로 되돌려보낸다.
 */
export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/login" element={<LoginPage />} />
      {/* PRD v8.1: 실제로는 자체 회원가입 플로우가 없다 — UI만 존재, onSignup 미연결 */}
      <Route path="/signup" element={<SignupPage />} />
      <Route path="/ai-diagnosis" element={<AiDiagnosisStartPage />} />
      <Route path="/news" element={<RecommendationPage />} />
      <Route path="/saved" element={<SavedPage />} />
      <Route path="/mypage" element={<MyPage />} />
      <Route path="/start" element={<BuildingSpaceSelectPage />} />
      <Route path="/space-input" element={<SpaceInputPage />} />
      <Route path="/photo-upload" element={<PhotoUploadPage />} />
      <Route path="/ai-confirm" element={<AiConfirmPage />} />
      <Route path="/result" element={<ResultPage />} />
    </Routes>
  );
}
