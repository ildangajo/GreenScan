import { createContext, useContext, useState, type ReactNode } from "react";

/**
 * 목업 단계의 화면 간 공유 상태.
 *
 * 실제 확정 입력 스키마와 계산 API 계약은 docs/api-design.md 2.4절을 따른다.
 * 여기서는 화면 흐름(1~5단계)이 이어진다는 것을 보여주기 위한 최소 상태만 다룬다 —
 * 서버 저장, 유효성 검증, react-hook-form/zod 연동은 실제 API 연동 단계에서 붙인다.
 */
export type BuildingType = "detached_multi_household" | "apartment";
export type SpaceType = "living_room" | "main_bedroom" | "other";
export type WindowType = "single" | "double" | "triple";
export type LowE = "yes" | "no" | "unknown";
export type AnomalyConfirm = "suspected" | "none_observed";

export interface DiagnosisState {
  buildingType: BuildingType;
  spaceType: SpaceType;
  width: string;
  depth: string;
  height: string;
  floorArea: string;
  windowArea: string;
  wallArea: string;
  windowTypeConfirmed: WindowType;
  lowE: LowE;
  anomalyConfirmed: AnomalyConfirm;
}

const defaultState: DiagnosisState = {
  buildingType: "apartment",
  spaceType: "living_room",
  width: "",
  depth: "",
  height: "",
  floorArea: "",
  windowArea: "",
  wallArea: "",
  windowTypeConfirmed: "double",
  lowE: "unknown",
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
