import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import { useDiagnosis, type DiagnosisState } from "../../state/DiagnosisContext";

type NumericField = "width" | "depth" | "height" | "floorArea" | "windowArea" | "wallArea";

/** 화면 2: 공간 치수/면적 입력 (PRD v7 5.2 필수 입력) */
export default function SpaceInputPage() {
  const navigate = useNavigate();
  const { state, update } = useDiagnosis();

  const field = (label: string, key: NumericField, placeholder: string) => (
    <label className="flex flex-col gap-1">
      <span className="text-xs font-medium text-neutral-600">{label}</span>
      <input
        type="number"
        inputMode="decimal"
        value={state[key]}
        onChange={(e) => update({ [key]: e.target.value } as Partial<DiagnosisState>)}
        placeholder={placeholder}
        className="rounded-lg border border-neutral-300 px-3 py-2.5 text-sm outline-none focus:border-neutral-900"
      />
    </label>
  );

  return (
    <StepLayout
      step={2}
      title="대표 공간 치수를 입력하세요"
      subtitle={`${state.buildingType === "apartment" ? "아파트" : "단독·다가구주택"} · 거실 기준`}
      onNext={() => navigate("/photo-upload")}
      onBack={() => navigate("/start")}
    >
      <div className="flex flex-col gap-5">
        <div>
          <p className="mb-2 text-sm font-semibold">공간 치수</p>
          <div className="grid grid-cols-3 gap-2">
            {field("가로 (m)", "width", "예: 4.2")}
            {field("세로 (m)", "depth", "예: 3.5")}
            {field("높이 (m)", "height", "예: 2.4")}
          </div>
        </div>

        {field("바닥면적 (m²) — 참고용, 계산에는 사용되지 않음", "floorArea", "예: 14.7")}
        <p className="rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-xs text-neutral-500">
          바닥면적은 가로×세로 입력값과의 교차 확인용으로만 쓰입니다.
        </p>

        <div>
          <p className="mb-2 text-sm font-semibold">창호</p>
          {field("창호 합산면적 (m²)", "windowArea", "예: 3.6")}
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold">벽체</p>
          {field("외기 접촉 벽체 합산면적 (m²)", "wallArea", "예: 12.0")}
          <p className="mt-2 rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-xs text-neutral-500">
            외기 접촉 벽체 순면적 = 벽체 합산면적 − 창호 합산면적. 0 이하이면 다음 단계로 진행할 수 없습니다.
          </p>
        </div>
      </div>
    </StepLayout>
  );
}
