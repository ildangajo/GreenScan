import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import { useDiagnosis, type BuildingType, type SpaceType } from "../../state/DiagnosisContext";

const BUILDING_TYPES: { value: BuildingType; label: string; note: string }[] = [
  { value: "detached_multi_household", label: "단독·다가구주택", note: "개선 목표 U값: 공동주택 외 기준" },
  { value: "apartment", label: "아파트", note: "개선 목표 U값: 공동주택 기준 · 세대 내 대표 공간 1개만 지원" },
];

const SPACE_TYPES: { value: SpaceType; label: string }[] = [
  { value: "living_room", label: "거실" },
  { value: "main_bedroom", label: "주침실" },
  { value: "other", label: "기타 대표 공간" },
];

/** 화면 1: 건물 유형 + 대표 공간 선택 (PRD v7 2.1 흐름 1단계) */
export default function BuildingSpaceSelectPage() {
  const navigate = useNavigate();
  const { state, update } = useDiagnosis();

  return (
    <StepLayout
      step={1}
      title="건물 유형을 선택하세요"
      subtitle="대표 공간 1개를 기준으로 진단합니다"
      hideBack
      onNext={() => navigate("/space-input")}
    >
      <div className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <span className="text-sm font-medium text-neutral-700">건물 유형</span>
          <div className="flex flex-col gap-2">
            {BUILDING_TYPES.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => update({ buildingType: option.value })}
                className={`rounded-lg border px-4 py-3 text-left ${
                  state.buildingType === option.value
                    ? "border-neutral-900 bg-neutral-50"
                    : "border-neutral-200"
                }`}
              >
                <p className="text-sm font-semibold">{option.label}</p>
                <p className="mt-0.5 text-xs text-neutral-500">{option.note}</p>
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <span className="text-sm font-medium text-neutral-700">대표 공간</span>
          <div className="flex flex-wrap gap-2">
            {SPACE_TYPES.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => update({ spaceType: option.value })}
                className={`rounded-full border px-4 py-2 text-sm ${
                  state.spaceType === option.value
                    ? "border-neutral-900 bg-neutral-900 text-white"
                    : "border-neutral-300 text-neutral-700"
                }`}
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>

        <p className="rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-xs text-neutral-500">
          상가, 공용부·복도·계단실, 세대 전체 진단은 지원하지 않습니다. 로그인/계정 없이 진행됩니다.
        </p>
      </div>
    </StepLayout>
  );
}
