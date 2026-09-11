import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";
import { useDiagnosis } from "../../state/DiagnosisContext";
import { calculateDiagnosis, type CalculateRequest, type CalculateResponse } from "../../api/diagnoses";
import { ApiError } from "../../api/http";

/**
 * 화면 5: 결과 화면 (PRD v7 7.5 결과와 시나리오 + 디자인팀 시안 반영).
 *
 * 이전엔 docs/api-design.md 2.4절 Mock JSON을 그대로 하드코딩해서 보여줬는데,
 * 이제 실제 POST /api/v1/diagnoses/calculate를 호출해서 받은 값을 그대로
 * 쓴다(backend/app/schemas/calculation.py CalculateResponse). 화면 진입 시
 * DiagnosisContext에 쌓인 1~4단계 입력을 CalculateRequest로 조립해 호출한다.
 *
 * 백엔드 응답에 없는 항목은 뺐다 — "에너지 효율 레벨(LV.3)"과 "예상 개선
 * 비용" 텍스트는 실제 계산 응답 어디에도 대응하는 필드가 없는 PM 임시
 * placeholder였다(docs/prd-v7-deviations.md #1, #3). 등급 산정 로직/견적
 * 근거값 정책이 정해지면 다시 추가하면 된다. 대신 백엔드가 실제로 주는
 * unit_scope_disclaimer(고지 문구)와 wall_anomaly_notice(벽체 이상 흔적
 * 안내)를 그대로 쓴다.
 */

const URGENCY_STYLE = ["bg-red-50 text-red-600", "bg-amber-50 text-amber-600", "bg-neutral-100 text-neutral-600"];
const URGENCY_BADGE_STYLE = ["bg-red-500", "bg-amber-500", "bg-neutral-400"];
const URGENCY_LABEL = ["긴급", "주의", "권장"];

function urgencyIndex(priority: number) {
  return Math.min(priority - 1, URGENCY_LABEL.length - 1);
}

/**
 * PRD v8.2 9.1: "총량 수준" 등급은 서버가 내려주는 별도 필드가 아니라
 * (산정 임계값 정책 미확정, docs/db-spec.md 8장), 프론트가 기존 scenarios의
 * 우선순위(감소량 큰 순으로 이미 정렬됨)만 보고 판단한다 — 가장 시급한
 * 개선 시나리오의 등급을 총량 수준 등급으로 그대로 쓴다. 임의의 %
 * 임계값을 새로 만들지 않는다.
 */
function overallUrgencyIndex(scenarios: CalculateResponse["scenarios"]): number {
  const topPriority = scenarios.reduce(
    (min, s) => Math.min(min, s.priority),
    scenarios[0]?.priority ?? URGENCY_LABEL.length,
  );
  return urgencyIndex(topPriority);
}

type LoadState =
  | { status: "loading" }
  | { status: "ok"; data: CalculateResponse }
  | { status: "error"; code?: string; message: string };

export default function ResultPage() {
  const navigate = useNavigate();
  const { state } = useDiagnosis();
  const [result, setResult] = useState<LoadState>({ status: "loading" });

  useEffect(() => {
    if (!state.regionId) {
      setResult({
        status: "error",
        message: "건물 주소가 확인되지 않았어요. 처음(AI 분석하기)으로 돌아가 주소를 확인해주세요.",
      });
      return;
    }

    const payload: CalculateRequest = {
      building: {
        building_type: state.buildingType,
        representative_space_type: state.spaceType,
        construction_year_range: state.constructionYearRange,
      },
      space: {
        width_m: Number(state.width),
        depth_m: Number(state.depth),
        height_m: Number(state.height),
        floor_area_m2: Number(state.floorArea),
        input_source: "manual",
      },
      window: {
        total_area_m2: Number(state.windowArea),
        window_type: state.windowTypeConfirmed,
        low_e: state.lowE,
        input_source: "user_corrected",
      },
      wall: {
        exterior_total_area_m2: Number(state.wallArea),
        insulation_status: state.insulationStatus,
        visible_anomaly_confirmed: state.anomalyConfirmed,
        input_source: "user_corrected",
      },
      location: { region_id: state.regionId },
    };

    calculateDiagnosis(payload)
      .then((data) => setResult({ status: "ok", data }))
      .catch((err) => {
        if (err instanceof ApiError) {
          setResult({ status: "error", code: err.code, message: err.message });
        } else {
          setResult({ status: "error", message: "계산 요청에 실패했습니다." });
        }
      });
    // 진입 시 한 번만 — state는 이전 단계 입력이 끝난 뒤 더 바뀌지 않는다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <StepLayout
      step={5}
      title="GreenScan 추정 연간 열손실 분석"
      subtitle={`${state.buildingType === "apartment" ? "아파트" : "단독·다가구주택"} · 이 방 기준 · 비공식 추정치`}
      onBack={() => navigate("/ai-confirm")}
      onNext={() => navigate("/")}
      nextLabel="진단 종료"
    >
      {result.status === "loading" && (
        <div className="flex flex-col items-center gap-2 py-12 text-sm text-neutral-500">
          <span className="h-6 w-6 animate-spin rounded-full border-2 border-neutral-300 border-t-neutral-900" />
          계산 중입니다...
        </div>
      )}

      {result.status === "error" && (
        <div className="flex flex-col gap-3 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          <p className="font-semibold">{result.code ? `계산 실패 (${result.code})` : "계산 실패"}</p>
          <p>{result.message}</p>
          <button
            type="button"
            onClick={() => navigate("/space-input")}
            className="self-start rounded-lg border border-red-300 px-3 py-1.5 text-xs font-medium text-red-700"
          >
            입력값 다시 확인하기
          </button>
        </div>
      )}

      {result.status === "ok" && (
        <div className="flex flex-col gap-5">
          {(() => {
            const uIdx = overallUrgencyIndex(result.data.scenarios);
            return (
              <div className="flex flex-col gap-2 rounded-lg border border-neutral-200 p-4 text-center">
                <p className="text-xs text-neutral-500">이 집의 열손실 총량 수준</p>
                <span
                  className={`self-center rounded-full px-4 py-1.5 text-lg font-bold text-white ${URGENCY_BADGE_STYLE[uIdx]}`}
                >
                  {URGENCY_LABEL[uIdx]}
                </span>
                <p className="text-[11px] text-neutral-400">참고용 추정치이며 실제와 다를 수 있습니다.</p>
              </div>
            );
          })()}

          <div className="rounded-lg border border-neutral-200 p-4">
            <p className="text-xs text-neutral-500">예상 연간 에너지 사용량 (대표 공간 기준 추정)</p>
            <p className="text-2xl font-bold text-neutral-900">
              {result.data.baseline.total_heat_loss_kwh.toLocaleString()}{" "}
              <span className="text-sm font-normal text-neutral-500">kWh/year</span>
            </p>
            {(() => {
              const windowShare = Math.round(
                (result.data.baseline.window_heat_loss_kwh / result.data.baseline.total_heat_loss_kwh) * 100,
              );
              return (
                <>
                  <div className="mt-3 flex h-3 overflow-hidden rounded-full border border-neutral-300">
                    <div className="bg-neutral-900" style={{ width: `${windowShare}%` }} />
                    <div className="bg-neutral-300" style={{ width: `${100 - windowShare}%` }} />
                  </div>
                  <div className="mt-1.5 flex justify-between text-[11px] text-neutral-500">
                    <span>창호 {result.data.baseline.window_heat_loss_kwh.toLocaleString()} kWh</span>
                    <span>벽체 {result.data.baseline.wall_heat_loss_kwh.toLocaleString()} kWh</span>
                  </div>
                </>
              );
            })()}
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold">개선 우선순위</p>
            <div className="flex flex-col gap-3">
              {result.data.scenarios.map((s) => {
                const uIdx = urgencyIndex(s.priority);
                return (
                  <div key={s.scenario_id} className="rounded-lg border border-neutral-200 p-3">
                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-2 text-sm font-semibold">
                        <span className="flex h-5 w-5 items-center justify-center rounded-full bg-neutral-900 text-[11px] text-white">
                          {s.priority}
                        </span>
                        {s.name}
                      </span>
                      <div className="flex items-center gap-1.5">
                        <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${URGENCY_STYLE[uIdx]}`}>
                          {URGENCY_LABEL[uIdx]}
                        </span>
                        <span className="text-sm font-semibold text-neutral-700">
                          −{Math.round(s.reduction_rate * 1000) / 10}%
                        </span>
                      </div>
                    </div>
                    <div className="mt-2 h-2 rounded-full bg-neutral-100">
                      <div
                        className="h-full rounded-full bg-neutral-800"
                        style={{ width: `${Math.min(s.reduction_rate * 100, 100)}%` }}
                      />
                    </div>
                    <div className="mt-1.5 text-xs text-neutral-500">
                      연간 {s.annual_reduction_kwh.toLocaleString()} kWh 감소 추정
                      {s.changed_components.length > 0 && ` · ${s.changed_components.join(", ")} 개선`}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="rounded-lg border border-neutral-200 p-3 text-xs text-neutral-600">
            {result.data.wall_anomaly_notice.message}
          </div>

          <p className="rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-[11px] leading-relaxed text-neutral-500">
            {result.data.unit_scope_disclaimer}
          </p>

          <p className="text-[10px] text-neutral-400">
            계산 버전 {result.data.calculation_version} · 기준 U값(창호 {result.data.reference_data_version.current_u_value_window} →
            목표 {result.data.reference_data_version.target_u_value}) · HDD {result.data.reference_data_version.hdd}
          </p>
        </div>
      )}
    </StepLayout>
  );
}
