import { Navigate, Route, Routes } from "react-router-dom";
import BuildingSpaceSelectPage from "../features/space-input/BuildingSpaceSelectPage";
import SpaceInputPage from "../features/space-input/SpaceInputPage";
import PhotoUploadPage from "../features/vision-analysis/PhotoUploadPage";
import AiConfirmPage from "../features/vision-analysis/AiConfirmPage";
import ResultPage from "../features/calculation-result/ResultPage";

/**
 * GreenScan MVP Must 흐름(PRD v7 2.1) 기준 5단계 목업 라우팅.
 * 화면 1(건물유형+대표공간)과 2(치수/면적 입력)는 features/space-input,
 * 화면 3(사진업로드)과 4(AI 후보확인)는 features/vision-analysis,
 * 화면 5(결과)는 features/calculation-result 아래에 둔다.
 */
export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/start" replace />} />
      <Route path="/start" element={<BuildingSpaceSelectPage />} />
      <Route path="/space-input" element={<SpaceInputPage />} />
      <Route path="/photo-upload" element={<PhotoUploadPage />} />
      <Route path="/ai-confirm" element={<AiConfirmPage />} />
      <Route path="/result" element={<ResultPage />} />
    </Routes>
  );
}
