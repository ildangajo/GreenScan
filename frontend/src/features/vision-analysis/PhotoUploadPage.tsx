import { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import {
  useDiagnosis,
  type WindowType,
  type LowE,
  type AnomalyConfirm,
} from "../../state/DiagnosisContext";
import { analyzePhoto, type PhotoAnalysisResponse, type PhotoCategory } from "../../api/photos";
import { ApiError } from "../../api/http";
import { checkPhotoBlur } from "./blurDetection";

/**
 * 화면 3: 사진 업로드 + AI 후보 확인 (원래 5단계였던 "사진 업로드"/"AI 확인"을
 * 합쳤다 — POST /api/v1/photos/analyze가 사진 1장당 즉시 후보를 돌려주는
 * 동기 API라서 업로드와 확인을 두 화면으로 나눌 이유가 없었다).
 *
 * api-spec.md 5.0절: 흐린 사진은 POST /api/v1/photos/analyze 호출 전
 * 클라이언트에서 먼저 걸러 재촬영을 안내한다(서버 판정을 대체하지 않음,
 * blurDetection.ts 참고). 블러로 판정돼도 강제로 계속 진행할 수 있다.
 *
 * 사진 없이도 다음 단계로 진행할 수 있다(PRD) — 그 경우 아래 확정 칩들은
 * 그냥 수동으로 고르면 된다. window_type_candidate/visible_anomaly_candidate가
 * unknown/not_applicable/unassessable이면 자동으로 값을 채우지 않고
 * 사용자가 직접 고르게 둔다.
 */

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

type SlotState =
  | { status: "empty" }
  | { status: "checking_blur"; fileName: string }
  | { status: "blurry"; fileName: string; file: File }
  | { status: "analyzing"; fileName: string }
  | { status: "done"; fileName: string; result: PhotoAnalysisResponse }
  | { status: "error"; fileName: string; message: string };

export default function PhotoUploadPage() {
  const navigate = useNavigate();
  const { state, update } = useDiagnosis();

  const [windowSlot, setWindowSlot] = useState<SlotState>({ status: "empty" });
  const [wallSlot, setWallSlot] = useState<SlotState>({ status: "empty" });

  const runAnalyze = async (category: PhotoCategory, file: File) => {
    const setSlot = category === "window" ? setWindowSlot : setWallSlot;
    setSlot({ status: "analyzing", fileName: file.name });
    try {
      const result = await analyzePhoto(category, file);
      setSlot({ status: "done", fileName: file.name, result });

      if (category === "window" && ["single", "double", "triple"].includes(result.window_type_candidate)) {
        update({ windowTypeConfirmed: result.window_type_candidate as WindowType });
      }
      if (category === "wall" && ["suspected", "none_observed"].includes(result.visible_anomaly_candidate)) {
        update({ anomalyConfirmed: result.visible_anomaly_candidate as AnomalyConfirm });
      }
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "사진 분석에 실패했습니다.";
      setSlot({ status: "error", fileName: file.name, message });
    }
  };

  const handlePick = async (category: PhotoCategory, file: File) => {
    const setSlot = category === "window" ? setWindowSlot : setWallSlot;
    setSlot({ status: "checking_blur", fileName: file.name });
    try {
      const { isBlurry } = await checkPhotoBlur(file);
      if (isBlurry) {
        setSlot({ status: "blurry", fileName: file.name, file });
        return;
      }
    } catch {
      // 블러 체크 자체가 실패해도(브라우저 호환성 등) 서버 분석은 계속 진행한다 —
      // 이건 어디까지나 사전 안내용 보조 체크일 뿐이다.
    }
    await runAnalyze(category, file);
  };

  return (
    <StepLayout
      step={3}
      title="창호와 벽체 사진을 올려주세요"
      subtitle="사진 없이도 아래 항목을 직접 선택해 진행할 수 있습니다"
      onNext={() => navigate("/result")}
      onBack={() => navigate("/space-input")}
    >
      <div className="flex flex-col gap-6">
        <PhotoSlot
          label="창호 사진"
          category="window"
          slot={windowSlot}
          onPick={(file) => handlePick("window", file)}
          onForceContinue={() => windowSlot.status === "blurry" && runAnalyze("window", windowSlot.file)}
        />
        {windowSlot.status === "done" && (
          <section className="-mt-3 rounded-lg border border-neutral-200 p-4">
            <ChipGroup
              label="창호 유형 확정"
              options={WINDOW_TYPES}
              value={state.windowTypeConfirmed}
              onChange={(v) => update({ windowTypeConfirmed: v })}
            />
            <ChipGroup
              label="Low-E 여부 (AI가 판별하지 않는 값 — 육안/시공 기록으로 확인)"
              options={LOW_E_OPTIONS}
              value={state.lowE}
              onChange={(v) => update({ lowE: v })}
            />
          </section>
        )}

        <PhotoSlot
          label="벽체 사진"
          category="wall"
          slot={wallSlot}
          onPick={(file) => handlePick("wall", file)}
          onForceContinue={() => wallSlot.status === "blurry" && runAnalyze("wall", wallSlot.file)}
        />
        {wallSlot.status === "done" && (
          <section className="-mt-3 rounded-lg border border-neutral-200 p-4">
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
        )}

        {/* 사진을 아예 안 올렸어도 수동 확정은 항상 열어둔다(PRD: 사진 없이도 진행 가능) */}
        {windowSlot.status === "empty" && wallSlot.status === "empty" && (
          <section className="rounded-lg border border-dashed border-neutral-300 p-4">
            <p className="mb-3 text-xs text-neutral-500">
              사진을 올리지 않으면 아래 항목을 직접 선택해서 진행할 수 있습니다.
            </p>
            <ChipGroup
              label="창호 유형"
              options={WINDOW_TYPES}
              value={state.windowTypeConfirmed}
              onChange={(v) => update({ windowTypeConfirmed: v })}
            />
            <ChipGroup label="Low-E 여부" options={LOW_E_OPTIONS} value={state.lowE} onChange={(v) => update({ lowE: v })} />
            <ChipGroup
              label="벽체 이상 흔적 여부"
              options={ANOMALY_OPTIONS}
              value={state.anomalyConfirmed}
              onChange={(v) => update({ anomalyConfirmed: v })}
            />
          </section>
        )}

        <div className="rounded-lg border border-neutral-200 p-3">
          <p className="mb-2 text-sm font-semibold">촬영 가이드</p>
          <ul className="flex flex-col gap-1 text-xs text-neutral-600">
            <li>— 창호는 프레임과 유리면이 함께 보이게 찍어주세요</li>
            <li>— 벽체는 의심 부위가 흐리지 않게 가까이서 찍어주세요</li>
            <li>— 어두움, 강한 반사, 원거리 촬영은 재촬영 대상입니다</li>
          </ul>
        </div>

        <p className="text-xs text-neutral-400">
          업로드한 사진은 AI 분석을 위해 외부 API로 전송되며, GreenScan 서버에는 원본이 저장되지 않습니다.
        </p>
      </div>
    </StepLayout>
  );
}

function PhotoSlot({
  label,
  category,
  slot,
  onPick,
  onForceContinue,
}: {
  label: string;
  category: PhotoCategory;
  slot: SlotState;
  onPick: (file: File) => void;
  onForceContinue: () => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const busy = slot.status === "checking_blur" || slot.status === "analyzing";

  return (
    <div>
      <button
        type="button"
        onClick={() => inputRef.current?.click()}
        disabled={busy}
        className="flex w-full items-center justify-between rounded-lg border border-neutral-300 px-4 py-3 text-left disabled:opacity-60"
      >
        <span className="text-sm font-medium">{label}</span>
        <span className="text-xs text-neutral-500">
          {slot.status === "empty" && "사진 선택"}
          {slot.status === "checking_blur" && "사진 확인 중..."}
          {slot.status === "analyzing" && "분석 중..."}
          {(slot.status === "done" || slot.status === "error" || slot.status === "blurry") && slot.fileName}
        </span>
      </button>
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) onPick(file);
          e.target.value = "";
        }}
      />

      {slot.status === "blurry" && (
        <div className="mt-2 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-700">
          <p className="font-semibold">사진이 흐려서 인식이 어려울 수 있어요.</p>
          <div className="mt-2 flex gap-2">
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="rounded-full border border-amber-600 px-3 py-1 text-[11px] font-medium text-amber-700"
            >
              다시 촬영
            </button>
            <button
              type="button"
              onClick={onForceContinue}
              className="rounded-full bg-amber-600 px-3 py-1 text-[11px] font-medium text-white"
            >
              그래도 분석하기
            </button>
          </div>
        </div>
      )}
      {slot.status === "done" && (
        <div className="mt-2 rounded-md bg-neutral-50 px-3 py-2 text-xs text-neutral-600">
          {slot.result.photo_quality === "retake_required" && (
            <p className="mb-1 font-semibold text-amber-600">사진 품질이 낮아 재촬영을 권장해요.</p>
          )}
          {slot.result.assessment_status !== "completed" ? (
            <p>AI가 이 사진에서 {category === "window" ? "창호" : "벽체"} 상태를 판별하지 못했어요. 아래에서 직접 선택해주세요.</p>
          ) : (
            <p>{slot.result.reason_summary || "AI 분석이 완료됐어요. 아래에서 확정해주세요."}</p>
          )}
        </div>
      )}
      {slot.status === "error" && (
        <p className="mt-2 rounded-md bg-red-50 px-3 py-2 text-xs text-red-600">{slot.message}</p>
      )}
    </div>
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
    <div className="mt-3 first:mt-0">
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
