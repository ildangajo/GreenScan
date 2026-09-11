import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import {
  useDiagnosis,
  type WindowType,
  type LowE,
  type AnomalyConfirm,
} from "../../state/DiagnosisContext";

const WINDOW_TYPES: { value: WindowType; label: string }[] = [
  { value: "single", label: "단창" },
  { value: "double", label: "복층창" },
  { value: "triple", label: "삼중창" },
];

const LOW_E_OPTIONS: { value: LowE; label: string }[] = [
  { value: "yes", label: "적용" },
  { value: "no", label: "미적용" },
  { value: "unknown", label: "모름" },
];

const ANOMALY_OPTIONS: { value: AnomalyConfirm; label: string }[] = [
  { value: "suspected", label: "있음 (현장 점검 권장)" },
  { value: "none_observed", label: "없음" },
];

/**
 * 화면 4: AI 후보 확인/수정 (PRD v7 6.3 사용자 확정 규칙).
 * 여기 표시된 "AI 후보" 텍스트는 실제 Vision 응답이 아니라 목업 샘플이다.
 * 실제 연동 시 POST /api/v1/photos/analyze 응답(docs/api-design.md 2.3절)으로 대체.
 */
export default function AiConfirmPage() {
  const navigate = useNavigate();
  const { state, update } = useDiagnosis();

  return (
    <StepLayout
      step={4}
      title="AI 분석 결과를 확인해주세요"
      subtitle="모든 항목은 확정 전 직접 수정할 수 있습니다"
      onNext={() => navigate("/result")}
      onBack={() => navigate("/photo-upload")}
    >
      <div className="flex flex-col gap-6">
        <section className="rounded-lg border border-neutral-200 p-4">
          <p className="text-sm font-semibold">창호 사진</p>
          <p className="mt-1 inline-block rounded-full bg-violet-50 px-2 py-0.5 text-[11px] font-medium text-violet-700">
            AI 후보: 복층창
          </p>
          <p className="mt-2 rounded-md bg-neutral-50 px-3 py-2 text-xs text-neutral-600">
            "창틀 이중 프레임과 유리 간격이 복층창 형태로 보입니다." — 실제 사양 확정치가 아닌 시각적
            후보입니다.
          </p>

          <ChipGroup
            label="창호 유형 확정"
            options={WINDOW_TYPES}
            value={state.windowTypeConfirmed}
            onChange={(v) => update({ windowTypeConfirmed: v })}
          />
          <ChipGroup
            label="Low-E 여부 (AI가 판별하지 않는 값)"
            options={LOW_E_OPTIONS}
            value={state.lowE}
            onChange={(v) => update({ lowE: v })}
          />
        </section>

        <section className="rounded-lg border border-neutral-200 p-4">
          <p className="text-sm font-semibold">벽체 사진</p>
          <p className="mt-1 inline-block rounded-full bg-violet-50 px-2 py-0.5 text-[11px] font-medium text-violet-700">
            AI 후보: 이상 흔적 있음
          </p>
          {/* 곰팡이/습도 문구는 docs/prd-v7-deviations.md #5의 확장 아이디어 예시 — 원인을
              확정하지 않고 여전히 현장 점검 권장 안내로만 다룬다. */}
          <p className="mt-2 rounded-md bg-neutral-50 px-3 py-2 text-xs text-neutral-600">
            "벽면 하단에 곰팡이로 추정되는 흔적이 있습니다. 습도가 높을 가능성이 있어요." — 원인
            진단이 아닌 현장 점검 권장 안내용 후보입니다.
          </p>

          <ChipGroup
            label="사진상 이상 흔적 여부 확정"
            options={ANOMALY_OPTIONS}
            value={state.anomalyConfirmed}
            onChange={(v) => update({ anomalyConfirmed: v })}
          />
          <p className="mt-2 rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-xs text-neutral-500">
            이 값은 결과 화면의 현장 점검 안내에만 반영되며, U값·면적·열손실 수치를 바꾸지 않습니다.
          </p>
        </section>
      </div>
    </StepLayout>
  );
}

function ChipGroup<T extends string>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <div className="mt-3">
      <p className="mb-1.5 text-xs font-medium text-neutral-600">{label}</p>
      <div className="flex flex-wrap gap-2">
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            className={`rounded-full border px-3 py-1.5 text-xs ${
              value === option.value
                ? "border-neutral-900 bg-neutral-900 text-white"
                : "border-neutral-300 text-neutral-700"
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
