import { useNavigate } from "react-router-dom";

/**
 * 홈 화면 — PRD v7 원안에는 없던 화면. 디자인팀 시안 검토 후 PM 결정으로 추가.
 * 자세한 배경은 docs/prd-v7-deviations.md #4 참고.
 *
 * "최근 분석한 방" 이력은 계정/로그인 없이 보여주기로 한 기능이라,
 * 저장 방식(브라우저 로컬 vs 서버 익명 ID)은 BE가 DB 작업 중 — 여기서는
 * 그 API가 나오기 전까지 자리만 잡아두는 목업 데이터를 쓴다.
 */
const MOCK_RECENT: {
  id: string;
  title: string;
  date: string;
  reductionRate: number;
  costRangeText: string;
}[] = [
  {
    id: "1",
    title: "서울시 강남구 OO아파트 · 거실",
    date: "2026.09.02",
    reductionRate: 0.437,
    costRangeText: "약 700~1,050만원",
  },
  {
    id: "2",
    title: "서울시 강북구 OO빌라 · 주침실",
    date: "2026.08.22",
    reductionRate: 0.24,
    costRangeText: "약 350~550만원",
  },
];

export default function HomePage() {
  const navigate = useNavigate();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col bg-white">
      <header className="px-5 pb-2 pt-6">
        <p className="text-xs font-medium text-neutral-400">GreenScan</p>
        <h1 className="mt-1 text-xl font-semibold text-neutral-900">
          우리 집 열손실, AI로 먼저 확인해보세요
        </h1>
      </header>

      <div className="px-5 pt-3">
        <button
          type="button"
          onClick={() => navigate("/start")}
          className="w-full rounded-xl bg-neutral-900 px-4 py-4 text-left text-white"
        >
          <p className="text-sm font-semibold">AI 진단 시작하기</p>
          <p className="mt-0.5 text-xs text-neutral-300">대표 공간 1개, 3분이면 충분해요 →</p>
        </button>
      </div>

      <main className="flex-1 overflow-y-auto px-5 py-5">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-semibold text-neutral-900">최근 분석한 방</p>
          <span className="text-xs text-neutral-400">전체보기</span>
        </div>

        <div className="flex flex-col gap-3">
          {MOCK_RECENT.map((item) => (
            <div key={item.id} className="rounded-lg border border-neutral-200 p-3">
              <div className="flex items-center justify-between">
                <p className="text-sm font-medium text-neutral-900">{item.title}</p>
                <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold text-emerald-700">
                  −{Math.round(item.reductionRate * 100)}%
                </span>
              </div>
              <div className="mt-1.5 flex items-center justify-between text-xs text-neutral-500">
                <span>{item.date}</span>
                <span>예상 개선 비용 {item.costRangeText}</span>
              </div>
            </div>
          ))}
        </div>

        <p className="mt-4 rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-[11px] leading-relaxed text-neutral-400">
          이 목록은 목업 데이터입니다. 이력 저장/조회 API가 연결되면 실제 데이터로 교체됩니다. 사진
          원본은 서버에 저장하지 않습니다.
        </p>
      </main>
    </div>
  );
}
