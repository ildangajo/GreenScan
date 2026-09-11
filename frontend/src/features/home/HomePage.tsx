import { useNavigate } from "react-router-dom";

/**
 * 홈 화면 — 디자인팀 Figma 시안(2026-09-11 공유 스크린샷) 기준 구현.
 *
 * 주의:
 * - 색상 팔레트는 스크린샷에서 눈대중으로 추출한 근사값이다(tailwind.config.js `brand.*`).
 *   Figma Dev Mode에서 정확한 hex를 받으면 팔레트만 교체하면 된다.
 * - 건물 사진은 실제 자산이 없어 그라디언트 placeholder로 대체했다. 실제 이미지 URL이
 *   생기면 <div className="thumb-placeholder"> 자리를 <img>로만 바꾸면 된다.
 * - 하단 탭의 "추천" 라벨은 스크린샷 그대로 뒀다. PRD v8에서는 이 탭을 "환경 뉴스"로
 *   바꾸기로 했으므로(docs/prd/GreenScan_PRD_v8.md 6.3절), 라벨을 바꿀 땐 아래
 *   NAV_ITEMS 배열의 label 한 줄만 고치면 된다.
 * - "최근 분석한 방" 이력은 계정 기반으로 저장될 예정이라 지금은 목업 데이터다
 *   (docs/prd-v7-deviations.md #4 참고). 실제 이력 API가 연결되면 이 배열을 교체한다.
 */

interface RecentBuilding {
  id: string;
  title: string;
  date: string;
  reductionRate: number;
  costText: string;
}

const MOCK_RECENT: RecentBuilding[] = [
  { id: "1", title: "서울시 강남구 OO빌딩", date: "2026.07.02", reductionRate: 0.52, costText: "1,300만원" },
  { id: "2", title: "서울시 강북구 OO카페", date: "2024.04.22", reductionRate: 0.24, costText: "620만원" },
  { id: "3", title: "서울시 강서구 OO빌라", date: "2025.11.12", reductionRate: 0.21, costText: "430만원" },
  { id: "4", title: "서울시 송파구 OO빌딩", date: "2026.09.09", reductionRate: 0.6, costText: "1,850만원" },
];

const NAV_ITEMS = [
  { key: "home", label: "홈", hasDot: true },
  { key: "map", label: "위치", hasDot: true },
  { key: "saved", label: "저장", hasDot: false },
  { key: "news", label: "추천", hasDot: false },
  { key: "mypage", label: "마이페이지", hasDot: false },
] as const;

export default function HomePage() {
  const navigate = useNavigate();

  return (
    <div className="relative mx-auto flex min-h-screen w-full max-w-md flex-col bg-white">
      {/* 상단 검색바 + 알림 */}
      <div className="flex items-center gap-3 px-4 pb-3 pt-5">
        <div className="flex flex-1 items-center rounded-full border border-brand-100 bg-white px-4 py-3 shadow-sm">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="mr-2 shrink-0">
            <circle cx="11" cy="11" r="7" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            type="text"
            placeholder="어떤 건물을 찾으시나요?"
            className="w-full text-sm text-neutral-700 placeholder:text-neutral-400 outline-none"
          />
        </div>
        <button
          type="button"
          aria-label="알림"
          className="relative flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white shadow-sm"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#374151" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" />
            <path d="M13.73 21a2 2 0 0 1-3.46 0" />
          </svg>
          <span className="absolute right-2.5 top-2.5 h-2 w-2 rounded-full bg-red-500" />
        </button>
      </div>

      <main className="flex-1 overflow-y-auto px-4 pb-28">
        {/* 히어로 배너 */}
        <button
          type="button"
          onClick={() => navigate("/start")}
          className="relative block w-full overflow-hidden rounded-2xl text-left"
          style={{ aspectRatio: "4 / 3" }}
        >
          <div
            className="absolute inset-0"
            style={{
              background:
                "linear-gradient(135deg, #cfe9dd 0%, #9fcbb4 35%, #6fa98c 70%, #3f7a5f 100%)",
            }}
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-black/10 to-transparent" />
          <div className="absolute left-4 top-4 inline-flex items-center gap-1 rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-neutral-900 shadow">
            AI 진단 시작하기
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#111827" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </div>
          <div className="absolute bottom-8 left-4 right-4 text-2xl font-bold leading-tight text-white">
            이런 리모델링
            <br />
            가능하다고?
          </div>
          <div className="absolute bottom-3 left-0 right-0 flex justify-center gap-1.5">
            {[0, 1, 2, 3, 4].map((i) => (
              <span
                key={i}
                className={`h-1.5 rounded-full transition-all ${
                  i === 0 ? "w-4 bg-brand-400" : "w-1.5 bg-white/70"
                }`}
              />
            ))}
          </div>
        </button>

        {/* 최근 분석한 건물 */}
        <div className="mt-6 flex items-center justify-between">
          <h2 className="text-base font-bold text-neutral-900">최근 분석한 건물</h2>
          <button type="button" className="flex items-center gap-0.5 text-sm font-medium text-brand-500">
            전체보기
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </button>
        </div>

        <div className="mt-3 flex flex-col gap-3">
          {MOCK_RECENT.map((b) => (
            <RecentBuildingCard key={b.id} building={b} />
          ))}
        </div>
      </main>

      {/* 진단 시작 FAB */}
      <button
        type="button"
        onClick={() => navigate("/start")}
        aria-label="새 진단 시작하기"
        className="absolute bottom-24 right-5 flex h-14 w-14 items-center justify-center rounded-full bg-brand-500 text-white shadow-lg shadow-brand-500/30"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <line x1="12" y1="5" x2="12" y2="19" />
          <line x1="5" y1="12" x2="19" y2="12" />
        </svg>
      </button>

      {/* 하단 탭바 */}
      <nav className="sticky bottom-0 flex justify-around border-t border-neutral-100 bg-white px-2 py-2">
        {NAV_ITEMS.map((item) => (
          <button
            key={item.key}
            type="button"
            className={`relative flex flex-col items-center gap-1 px-2 py-1.5 text-[11px] ${
              item.key === "home" ? "text-neutral-900" : "text-neutral-400"
            }`}
          >
            <NavIcon name={item.key} active={item.key === "home"} />
            {item.hasDot && <span className="absolute right-1 top-0.5 h-1.5 w-1.5 rounded-full bg-red-500" />}
            <span className={item.key === "home" ? "font-semibold" : ""}>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

function RecentBuildingCard({ building }: { building: RecentBuilding }) {
  return (
    <button
      type="button"
      className="flex items-center gap-3 rounded-2xl border border-neutral-100 bg-white p-3 text-left shadow-sm"
    >
      <div
        className="h-20 w-20 shrink-0 rounded-xl"
        style={{
          background: "linear-gradient(160deg, #e4efe9 0%, #b9d9c7 50%, #7fae93 100%)",
        }}
      />
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-2">
          <p className="truncate text-sm font-bold text-neutral-900">{building.title}</p>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#B0B0B0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0">
            <path d="M9 6l6 6-6 6" />
          </svg>
        </div>
        <div className="mt-1 flex items-center gap-2">
          <span className="rounded-full bg-brand-50 px-2 py-0.5 text-[10px] font-semibold text-brand-600">분석완료</span>
          <span className="text-[11px] text-neutral-400">{building.date}</span>
        </div>
        <div className="mt-2 grid grid-cols-2 gap-2">
          <div>
            <p className="text-[10px] text-neutral-400">에너지 절감률</p>
            <p className="text-sm font-bold text-brand-500">{Math.round(building.reductionRate * 100)}%</p>
          </div>
          <div>
            <p className="text-[10px] text-neutral-400">예상 비용</p>
            <p className="text-sm font-bold text-neutral-900">{building.costText}</p>
          </div>
        </div>
      </div>
    </button>
  );
}

function NavIcon({ name, active }: { name: string; active: boolean }) {
  const stroke = active ? "#111827" : "#9CA3AF";
  const common = { width: 22, height: 22, viewBox: "0 0 24 24", fill: "none", stroke, strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

  switch (name) {
    case "home":
      return (
        <svg {...common}>
          <path d="M3 11 12 4l9 7" />
          <path d="M5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9" />
        </svg>
      );
    case "map":
      return (
        <svg {...common}>
          <path d="M12 21s-7-6.1-7-11a7 7 0 0 1 14 0c0 4.9-7 11-7 11Z" />
          <circle cx="12" cy="10" r="2.5" />
        </svg>
      );
    case "saved":
      return (
        <svg {...common}>
          <path d="M20.8 4.6c-1.6-1.6-4.2-1.6-5.8 0L12 7.6l-3-3c-1.6-1.6-4.2-1.6-5.8 0-1.6 1.6-1.6 4.2 0 5.8l8.8 8.8 8.8-8.8c1.6-1.6 1.6-4.2 0-5.8Z" />
        </svg>
      );
    case "news":
      return (
        <svg {...common}>
          <path d="m12 2 2.9 6.6 7.1.6-5.4 4.7 1.6 7-6.2-3.8-6.2 3.8 1.6-7-5.4-4.7 7.1-.6L12 2Z" />
        </svg>
      );
    case "mypage":
      return (
        <svg {...common}>
          <circle cx="12" cy="8" r="4" />
          <path d="M4 21c0-4 3.6-7 8-7s8 3 8 7" />
        </svg>
      );
    default:
      return null;
  }
}
