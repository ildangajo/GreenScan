import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import { useDiagnosis } from "../../state/DiagnosisContext";

/**
 * 화면 5: 결과 화면 (PRD v7 7.5 결과와 시나리오).
 * 아래 수치는 docs/api-design.md 2.4절 Mock JSON과 동일한 샘플값이다 — 실제로는
 * POST /api/v1/diagnoses/calculate 응답으로 대체한다. 위험도 등급(낮음/보통/높음)은
 * PRD 원칙상 표시하지 않는다.
 */
const MOCK_RESULT = {
  baselineTotalKwh: 1352.5,
  windowKwh: 812.4,
  wallKwh: 540.1,
  scenarios: [
    { priority: 1, name: "창호 개선", reductionKwh: 410.2, reductionRate: 0.303 },
    { priority: 2, name: "벽체 개선", reductionKwh: 210.5, reductionRate: 0.156 },
    { priority: 3, name: "복합 개선", reductionKwh: 590.8, reductionRate: 0.437 },
  ],
};

export default function ResultPage() {
  const navigate = useNavigate();
  const { state } = useDiagnosis();
  const windowShare = Math.round((MOCK_RESULT.windowKwh / MOCK_RESULT.baselineTotalKwh) * 100);

  return (
    <StepLayout
      step={5}
      title="GreenScan 추정 연간 열손실 분석"
      subtitle={`${state.buildingType === "apartment" ? "아파트" : "단독·다가구주택"} · 이 방 기준 · 비공식 추정치`}
      onBack={() => navigate("/ai-confirm")}
      onNext={() => navigate("/start")}
      nextLabel="진단 종료"
    >
      <div className="flex flex-col gap-5">
        <div className="rounded-lg border border-neutral-200 p-4">
          <p className="text-xs text-neutral-500">기준선 추정 연간 열손실</p>
          <p className="text-2xl font-bold text-neutral-900">
            {MOCK_RESULT.baselineTotalKwh.toLocaleString()}{" "}
            <span className="text-sm font-normal text-neutral-500">kWh/year</span>
          </p>
          <div className="mt-3 flex h-3 overflow-hidden rounded-full border border-neutral-300">
            <div className="bg-neutral-900" style={{ width: `${windowShare}%` }} />
            <div className="bg-neutral-300" style={{ width: `${100 - windowShare}%` }} />
          </div>
          <div className="mt-1.5 flex justify-between text-[11px] text-neutral-500">
            <span>창호 {MOCK_RESULT.windowKwh} kWh</span>
            <span>벽체 {MOCK_RESULT.wallKwh} kWh</span>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold">개선 시나리오</p>
          <div className="flex flex-col gap-3">
            {MOCK_RESULT.scenarios.map((s) => (
              <div key={s.name} className="rounded-lg border border-neutral-200 p-3">
                <div className="flex items-center justify-between">
                  <span className="flex items-center gap-2 text-sm font-semibold">
                    <span className="flex h-5 w-5 items-center justify-center rounded-full bg-neutral-900 text-[11px] text-white">
                      {s.priority}
                    </span>
                    {s.name}
                  </span>
                  <span className="text-sm font-semibold text-neutral-700">
                    −{Math.round(s.reductionRate * 1000) / 10}%
                  </span>
                </div>
                <div className="mt-2 h-2 rounded-full bg-neutral-100">
                  <div
                    className="h-full rounded-full bg-neutral-800"
                    style={{ width: `${s.reductionRate * 100}%` }}
                  />
                </div>
                <p className="mt-1.5 text-xs text-neutral-500">연간 {s.reductionKwh} kWh 감소 추정</p>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-lg border border-neutral-200 p-3 text-xs text-neutral-600">
          {state.anomalyConfirmed === "suspected"
            ? "사진상 이상 흔적이 확인되었습니다. 현장 점검을 권장합니다."
            : "사진상 뚜렷한 이상 흔적은 확인되지 않았습니다."}
          <p className="mt-1 text-neutral-400">
            이 안내는 현장 점검 참고용이며, 위 열손실 수치에는 영향을 주지 않습니다.
          </p>
        </div>

        <p className="rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-[11px] leading-relaxed text-neutral-500">
          이 결과는 대표 공간 1개 기준 비공식 추정치입니다. 천장, 바닥, 환기, 침기, 일사, 난방기기 효율,
          사용 습관은 포함하지 않습니다. 실제 U값·단열 상태·구조 안전성을 확정하지 않으며, 전문가 현장
          진단을 대체하지 않습니다.
        </p>
      </div>
    </StepLayout>
  );
}
