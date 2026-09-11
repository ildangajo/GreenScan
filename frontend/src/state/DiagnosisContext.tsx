import { createContext, useContext, useState, type ReactNode } from "react";

/**
 * 5단계 화면이 공유하는 진단 입력 상태.
 *
 * 값들은 실제 계산 API 계약(backend/app/schemas/diagnosis.py CalculateRequest,
 * api-spec.md 2.4)의 enum 문자열과 정확히 같은 값을 쓴다 — 이 상태를 그대로
 * ResultPage에서 CalculateRequest로 조립해 POST /diagnoses/calculate를 부른다
 * (features/calculation-result/ResultPage.tsx 참고). 필드명이 백엔드와 달라도
 * (예: windowTypeConfirmed → window_type) *값*만 정확히 일치하면 되고, 조립
 * 단계에서 필드명을 매핑한다.
 */
export type BuildingType = "detached_multi_household" | "apartment";
export type SpaceType = "living_room" | "main_bedroom" | "other";
export type WindowType = "single" | "double" | "triple";
export type LowE = "yes" | "no" | "unknown";
export type InsulationStatus = "none" | "partial" | "good";
export type AnomalyConfirm = "suspected" | "none_observed";

export interface DiagnosisState {
  buildingType: BuildingType;
  spaceType: SpaceType;
  /** 홈 히어로 배너 "AI 진단 시작하기" → AiDiagnosisStartPage에서 입력한 주소 원문(표시용) */
  address: string;
  /** 위 주소를 /api/v1/map/geocode로 확인해서 얻은 region_id. 비어있으면 아직 확인 전(또는 실패) */
  regionId: string;
  /** reference/options의 construction_year_ranges 중 하나의 value */
  constructionYearRange: string;
  width: string;
  depth: string;
  height: string;
  floorArea: string;
  windowArea: string;
  wallArea: string;
  windowTypeConfirmed: WindowType;
  lowE: LowE;
  insulationStatus: InsulationStatus;
  anomalyConfirmed: AnomalyConfirm;
}

const defaultState: DiagnosisState = {
  buildingType: "apartment",
  spaceType: "living_room",
  address: "",
  regionId: "",
  constructionYearRange: "",
  width: "",
  depth: "",
  height: "",
  floorArea: "",
  windowArea: "",
  wallArea: "",
  windowTypeConfirmed: "double",
  lowE: "unknown",
  insulationStatus: "partial",
  anomalyConfirmed: "none_observed",
};

interface DiagnosisContextValue {
  state: DiagnosisState;
  update: (patch: Partial<DiagnosisState>) => void;
}

const DiagnosisContext = createContext<DiagnosisContextValue | null>(null);

export function DiagnosisProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<DiagnosisState>(defaultState);
  const update = (patch: Partial<DiagnosisState>) =>
    setState((prev) => ({ ...prev, ...patch }));

  return (
    <DiagnosisContext.Provider value={{ state, update }}>
      {children}
    </DiagnosisContext.Provider>
  );
}

export function useDiagnosis() {
  const ctx = useContext(DiagnosisContext);
  if (!ctx) {
    throw new Error("useDiagnosis must be used within DiagnosisProvider");
  }
  return ctx;
}
