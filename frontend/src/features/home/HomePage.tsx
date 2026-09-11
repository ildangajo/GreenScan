import { useState } from "react";
import { useNavigate } from "react-router-dom";
import buildingGangnam from "./assets/building-gangnam.png";
import buildingGangbuk from "./assets/building-gangbuk.png";
import chevronIcon from "./assets/chevron.svg";
import heroHouse from "./assets/hero-house.png";

/**
 * 홈 화면 — 디자인팀 Figma 시안(2026-09-11 공유 스크린샷) 기준 구현.
 *
 * 주의:
 * - "최근 분석한 건물" 섹션(Figma node 18:27)과 히어로 배너(node 18:28)는 Figma
 *   Dev Mode에서 받은 정확한 색상/치수/이미지를 그대로 반영했다(#176b52 그린
 *   텍스트, rgba(47,203,170,.8) 배지, 20px 라운드 썸네일, 359:190 배너 비율 등).
 *   하단 탭은 아직 근사 팔레트(tailwind.config.js `brand.*`)를 쓴다 — Dev Mode
 *   데이터를 받으면 같은 방식으로 교체하면 된다.
 * - 히어로 배너, 강남/강북 카드 썸네일은 Figma에서 내보낸 실제 자산(./assets)을
 *   사용한다. 강서/송파 카드는 해당 노드에 내보낼 자산이 없어 그라디언트
 *   placeholder를 유지했다 — 실제 이미지가 생기면 두 항목의 `thumb` 필드만
 *   채우면 된다.
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
  thumb?: string;
}

const MOCK_RECENT: RecentBuilding[] = [
  { id: "1", title: "서울시 강남구 OO빌딩", date: "2026.07.02", reductionRate: 0.52, costText: "1,300만원", thumb: buildingGangnam },
  { id: "2", title: "서울시 강북구 OO카페", date: "2024.04.22", reductionRate: 0.24, costText: "620만원", thumb: buildingGangbuk },
  { id: "3", title: "서울시 강서구 OO빌라", date: "2025.11.12", reductionRate: 0.21, costText: "430만원" },
  { id: "4", title: "서울시 송파구 OO빌딩", date: "2026.09.09", reductionRate: 0.6, costText: "1,850만원" },
  // 아래는 스크롤 동작(고정 헤더 + 리스트 스크롤) 테스트용으로 추가한 목업 항목.
  // 실제 이력 API 연결 시 이 배열 전체가 교체된다.
  { id: "5", title: "서울시 서초구 OO오피스텔", date: "2026.03.15", reductionRate: 0.38, costText: "980만원" },
  { id: "6", title: "서울시 마포구 OO상가", date: "2025.08.21", reductionRate: 0.45, costText: "1,120만원" },
  { id: "7", title: "서울시 영등포구 OO빌딩", date: "2024.12.02", reductionRate: 0.29, costText: "760만원" },
  { id: "8", title: "서울시 성동구 OO주택", date: "2026.01.30", reductionRate: 0.55, costText: "1,470만원" },
];

const NAV_ITEMS = [
  { key: "home", label: "홈", hasDot: true },
  { key: "map", label: "위치", hasDot: true },
  { key: "saved", label: "저장", hasDot: false },
  { key: "news", label: "추천", hasDot: false },
  { key: "mypage", label: "마이페이지", hasDot: false },
] as const;

const FAB_MENU_ITEMS = [
  { key: "terms", label: "이용약관" },
  { key: "support", label: "고객센터" },
] as const;

export default function HomePage() {
  const navigate = useNavigate();
  const [fabOpen, setFabOpen] = useState(false);

  return (
    <div className="relative mx-auto flex h-screen w-full max-w-md flex-col overflow-hidden bg-white">
      {/* 상단 검색바 + 알림 — 스크롤해도 항상 화면에 고정 */}
      <div className="z-20 flex shrink-0 items-center gap-3 bg-white px-4 pb-3 pt-5">
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

      {/*
        히어로 배너는 검색바 바로 아래에 고정된 배경(z-0)으로 깔려 있고,
        "최근 분석한 건물" 패널(z-10)은 그 위를 덮는 스크롤 오버레이다.
        오버레이 맨 앞의 투명 스페이서가 히어로와 같은 높이를 차지해 초기에는
        히어로가 그대로 보이다가, 스크롤하면 패널이 자연스럽게 위로 올라오며
        히어로를 덮고, 검색바 바로 아래(sticky top-0)에 닿으면 멈춘 뒤로는
        카드 리스트만 평범하게 스크롤된다.
      */}
      <div className="relative min-h-0 flex-1 overflow-hidden">
        {/* 히어로 배너 — 고정 배경, 패널에 덮여도 스크롤 자체는 하지 않는다 */}
        <button
          type="button"
          onClick={() => navigate("/ai-diagnosis")}
          className="absolute inset-x-4 top-0 z-0 block overflow-hidden rounded-2xl text-left"
          style={{ aspectRatio: "359 / 190" }}
        >
          <img
            src={heroHouse}
            alt=""
            className="absolute inset-0 h-full w-full object-cover opacity-80"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-black/10 to-transparent" />
          <div className="absolute left-[10px] top-[13px] inline-flex items-center gap-1 rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-neutral-900 shadow">
            AI 진단 시작하기
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#111827" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </div>
          <div className="absolute bottom-[38px] left-[13px] right-4 text-lg font-bold leading-tight text-white">
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

        {/*
          "최근 분석한 건물" 스크롤 오버레이. main 자체는 pointer-events-none —
          안 그러면 main의 빈 영역(투명 스페이서가 차지한, 히어로 위 구간)이
          클릭을 가로채서 히어로 배너를 아예 누를 수 없게 된다. 실제로 보이는
          흰 시트에만 pointer-events-auto로 다시 켜준다. 스크롤은 시트를 통해
          잡혀도 가장 가까운 스크롤 조상인 main으로 정상적으로 올라간다.
        */}
        <main className="absolute inset-0 z-10 overflow-y-auto pointer-events-none">
          {/* 히어로와 같은 높이의 투명 스페이서 — 이 구간만큼 스크롤해야 패널이 히어로를 다 덮는다 */}
          <div aria-hidden className="px-4" style={{ aspectRatio: "359 / 190" }} />

          {/*
            여기서부터는 불투명한 흰 시트 하나로 이어붙여서, 카드 사이 여백에서도
            뒤의 히어로가 절대 비치지 않게 한다(성기게 보이면 시트가 아니라
            개별 카드들이 떠 있는 것처럼 보여서 히어로가 새어 보이는 버그가 있었음).
          */}
          <div className="pointer-events-auto bg-white px-4 pb-28">
            {/*
              rounded-t-xl은 헤더 쪽에 둔다 — sticky로 고정되면 이 헤더가 곧
              시트의 "새 상단"이 되는데, sticky는 부모 박스와 별도로 그려지기
              때문에 둥근 모서리를 부모(시트)에만 주면 고정된 뒤에는 사라진다.
            */}
            <div className="sticky top-0 z-10 -mx-4 flex items-center justify-between rounded-t-[24px] bg-white px-4 pb-3 pt-4 shadow-[0_-2px_8px_0px_rgba(0,0,0,0.1)]">
              <h2 className="text-[14px] font-medium text-[#535353]">최근 분석한 건물</h2>
              <button type="button" className="flex items-center gap-0.5 text-[14px] font-medium text-[#176b52]">
                전체보기
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M5 12h14M13 6l6 6-6 6" />
                </svg>
              </button>
            </div>

            <div className="mt-4 flex flex-col gap-4">
              {MOCK_RECENT.map((b) => (
                <RecentBuildingCard key={b.id} building={b} />
              ))}
            </div>
          </div>
        </main>
      </div>

      {/* 메뉴 열렸을 때 바깥 영역 탭하면 닫힘 */}
      {fabOpen && (
        <div className="absolute inset-0 z-10" onClick={() => setFabOpen(false)} />
      )}

      {/* + 버튼 — 누르면 + 원이 위로 부드럽게 떠오르며 분신하듯 서브 메뉴 원이 생기고,
          FAB에서 멀어질수록(위로 갈수록) 색이 옅어짐 (Figma node 28:755) */}
      <div className="absolute bottom-24 right-5 z-20 flex flex-col items-end gap-3">
        {FAB_MENU_ITEMS.map((item, i) => {
          const distanceFromFab = FAB_MENU_ITEMS.length - 1 - i;
          const shade = "bg-[#2fcbaa]/80 text-white";
          return (
            <button
              key={item.key}
              type="button"
              // TODO: 고객센터/이용약관 콘텐츠·라우트가 확정되면 여기 연결
              onClick={() => setFabOpen(false)}
              style={{ transitionDelay: fabOpen ? `${distanceFromFab * 60}ms` : "0ms" }}
              className={`flex h-14 w-14 items-center justify-center rounded-full text-center text-[11px] font-semibold leading-tight shadow-lg transition-all duration-300 ease-out ${shade} ${
                fabOpen ? "translate-y-0 scale-100 opacity-100" : "pointer-events-none translate-y-4 scale-75 opacity-0"
              }`}
            >
              {item.label}
            </button>
          );
        })}

        <button
          type="button"
          onClick={() => setFabOpen((v) => !v)}
          aria-label={fabOpen ? "메뉴 닫기" : "더보기 메뉴 열기"}
          aria-expanded={fabOpen}
          className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-400 text-white shadow-lg shadow-brand-400/30"
        >
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="white"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            className={`transition-transform duration-200 ${fabOpen ? "rotate-45" : ""}`}
          >
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </button>
      </div>

      {/* 하단 탭바 */}
      <nav className="z-10 flex shrink-0 justify-around border-t border-neutral-100 bg-white px-2 py-2">
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
      className="relative flex h-[98px] w-full shrink-0 items-center gap-[13px] rounded-[20px] bg-white pl-[6px] pr-[21px] text-left shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]"
    >
      {building.thumb ? (
        <img
          src={building.thumb}
          alt=""
          className="h-[85px] w-[101px] shrink-0 rounded-[20px] object-cover"
        />
      ) : (
        <div
          className="h-[85px] w-[101px] shrink-0 rounded-[20px]"
          style={{
            background: "linear-gradient(160deg, #e4efe9 0%, #b9d9c7 50%, #7fae93 100%)",
          }}
        />
      )}
      <div className="min-w-0 flex-1">
        <p className="truncate text-[14px] font-semibold text-[#535353]">{building.title}</p>
        <div className="mt-[3px] flex items-center gap-[8px]">
          <span className="flex items-center rounded-[20px] bg-[#2fcbaa]/80 px-[6px] py-[2px] text-[7px] font-semibold text-white">분석완료</span>
          <span className="text-[8px] font-semibold text-[#535353]/80">{building.date}</span>
        </div>
        <div className="mt-[4px] flex gap-[3px]">
          <div className="h-[39px] w-[81px] shrink-0 rounded-[10px] bg-white px-[7px] pt-[4px] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
            <p className="text-[5px] font-medium text-[#535353]/80">에너지 절감률</p>
            <p className="mt-[4px] text-[16px] font-semibold leading-none text-[#176b52]">{Math.round(building.reductionRate * 100)}%</p>
          </div>
          <div className="h-[39px] w-[81px] shrink-0 rounded-[10px] bg-white px-[7px] pt-[4px] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
            <p className="text-[5px] font-medium text-[#535353]/80">예상 비용</p>
            <p className="mt-[4px] text-[14px] font-semibold leading-none text-[#176b52]">{building.costText}</p>
          </div>
        </div>
      </div>
      <img src={chevronIcon} alt="" className="absolute right-[14px] top-1/2 h-[9px] w-[4.5px] -translate-y-1/2" />
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
