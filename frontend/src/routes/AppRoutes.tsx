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
import ResultPage from "../features/calculation-result/ResultPage";

/**
 * GreenScan MVP Must 흐름(PRD v7 2.1) 기준 4단계 라우팅 + 홈 화면.
 * 홈 화면은 PRD 원안에는 없고 디자인팀 시안 검토 후 추가된 진입점이다
 * (docs/prd-v7-deviations.md #4 참고).
 * 화면 1(건물유형+대표공간)과 2(치수/면적 입력)는 features/space-input,
 * 화면 3(사진업로드+AI 후보확인, 2026-09-11 한 화면으로 합침)은
 * features/vision-analysis, 화면 4(결과)는 features/calculation-result
 * 아래에 둔다. 원래 사진업로드/AI확인이 별개 5단계였는데
 * POST /photos/analyze가 사진 1장당 즉시 후보를 주는 동기 API라 화면을
 * 나눌 이유가 없어서 하나로 합쳤다(components/ui/StepLayout.tsx 주석 참고).
 *
 * /ai-diagnosis: 홈 히어로 배너 "AI 진단 시작하기"의 진입 화면. 사진+주소만
 * 먼저 받고 "분석 시작하기"를 누르면 /start(건물유형 선택)로 이어져 이
 * 4단계 플로우를 그대로 탄다 — features/ai-diagnosis/AiDiagnosisStartPage
 * 파일 상단 주석 참고. 여기서 확인한 주소의 region_id를 DiagnosisContext에
 * 저장해두므로, /start에 region_id 없이 직접 들어오면 BuildingSpaceSelectPage가
 * 자동으로 /ai-diagnosis로 되돌려보낸다.
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
      <Route path="/result" element={<ResultPage />} />
    </Routes>
  );
}
