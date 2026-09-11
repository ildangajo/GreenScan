import { useNavigate } from "react-router-dom";

/**
 * 하단 탭바 — 홈/추천 화면 등 탭이 보여야 하는 모든 화면에서 공유한다.
 * 원래 HomePage.tsx 안에 있던 걸 여러 화면(추천 탭 등)에서 재사용하려고
 * 꺼냈다. "추천" 라벨은 PRD v8에서 "환경 뉴스"로 바뀌기로 했으므로
 * (docs/prd/GreenScan_PRD_v8.md 6.3절) 바꿀 땐 아래 NAV_ITEMS의 label
 * 한 줄만 고치면 된다. 위치/마이페이지는 아직 화면이 없어 탭을 눌러도
 * 반응이 없다 — 해당 화면이 생기면 NAV_ROUTES에 경로만 추가하면 된다.
 */

export type NavKey = "home" | "map" | "saved" | "news" | "mypage";

const NAV_ITEMS: { key: NavKey; label: string; hasDot: boolean }[] = [
  { key: "home", label: "홈", hasDot: true },
  { key: "map", label: "위치", hasDot: true },
  { key: "saved", label: "저장", hasDot: false },
  { key: "news", label: "추천", hasDot: false },
  { key: "mypage", label: "마이페이지", hasDot: false },
];

const NAV_ROUTES: Partial<Record<NavKey, string>> = {
  home: "/",
  saved: "/saved",
  news: "/news",
};

export default function BottomNav({ active }: { active: NavKey }) {
  const navigate = useNavigate();

  return (
    <nav className="z-10 flex shrink-0 justify-around border-t border-neutral-100 bg-white px-2 py-2">
      {NAV_ITEMS.map((item) => (
        <button
          key={item.key}
          type="button"
          onClick={() => {
            const to = NAV_ROUTES[item.key];
            if (to) navigate(to);
          }}
          className={`relative flex flex-col items-center gap-1 px-2 py-1.5 text-[11px] ${
            item.key === active ? "text-neutral-900" : "text-neutral-400"
          }`}
        >
          <NavIcon name={item.key} active={item.key === active} />
          {item.hasDot && <span className="absolute right-1 top-0.5 h-1.5 w-1.5 rounded-full bg-red-500" />}
          <span className={item.key === active ? "font-semibold" : ""}>{item.label}</span>
        </button>
      ))}
    </nav>
  );
}

function NavIcon({ name, active }: { name: NavKey; active: boolean }) {
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
