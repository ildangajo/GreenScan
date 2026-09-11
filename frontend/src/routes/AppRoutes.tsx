import { Route, Routes } from "react-router-dom";
import HomePage from "../features/home/HomePage";
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
 */
export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/start" element={<BuildingSpaceSelectPage />} />
      <Route path="/space-input" element={<SpaceInputPage />} />
      <Route path="/photo-upload" element={<PhotoUploadPage />} />
      <Route path="/ai-confirm" element={<AiConfirmPage />} />
      <Route path="/result" element={<ResultPage />} />
    </Routes>
  );
}
