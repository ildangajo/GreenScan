import { useState } from "react";
import { useNavigate } from "react-router-dom";
import BottomNav from "../../components/ui/BottomNav";
import chevronLeftIcon from "../ai-diagnosis/assets/chevron-left.svg";
import buildingGangnam from "../home/assets/building-gangnam.png";
import buildingGangbuk from "../home/assets/building-gangbuk.png";

/**
 * 하단 탭바 "저장" 화면 — 와이어프레임 주석 그대로: "저장 이미지랑 에너지절감량
 * 등 간략하게 볼 수 있는 창". 홈의 "최근 분석한 건물" 카드보다 훨씬 간단하게
 * 썸네일 + 절감률만 보여준다.
 *
 * 지금은 목업 데이터를 하드코딩했다 — 실제로는 사용자가 하트/저장 버튼을 누른
 * 건물 목록 API로 교체될 자리다. 즐겨찾기 해제(저장 취소) 동작도 아직 없다.
 */

interface SavedBuilding {
  id: string;
  title: string;
  reductionRate: number;
  thumb?: string;
}

const MOCK_SAVED: SavedBuilding[] = [
  { id: "1", title: "서울시 강남구 OO빌딩", reductionRate: 0.52, thumb: buildingGangnam },
  { id: "2", title: "서울시 강북구 OO카페", reductionRate: 0.24, thumb: buildingGangbuk },
  { id: "3", title: "서울시 강서구 OO빌라", reductionRate: 0.21 },
  { id: "4", title: "서울시 송파구 OO빌딩", reductionRate: 0.6 },
];

export default function SavedPage() {
  const navigate = useNavigate();

  return (
    <div className="relative mx-auto flex h-screen w-full max-w-md flex-col overflow-hidden bg-white">
      <header className="flex shrink-0 items-center gap-[21px] px-[21px] pb-3 pt-5">
        <button type="button" onClick={() => navigate(-1)} aria-label="뒤로가기" className="shrink-0">
          <img src={chevronLeftIcon} alt="" className="h-6 w-6" />
        </button>
        <h1 className="text-[18px] font-normal text-[#535353]">저장</h1>
      </header>

      <main className="min-h-0 flex-1 overflow-y-auto px-4 pb-8">
        {MOCK_SAVED.length === 0 ? (
          <p className="mt-10 text-center text-sm text-neutral-400">저장한 건물이 아직 없어요.</p>
        ) : (
          <div className="flex flex-col gap-4">
            {MOCK_SAVED.map((b) => (
              <SavedBuildingCard key={b.id} building={b} />
            ))}
          </div>
        )}
      </main>

      <BottomNav active="saved" />
    </div>
  );
}

function SavedBuildingCard({ building }: { building: SavedBuilding }) {
  // TODO: 지금은 하트를 눌러도 UI만 바뀐다. 실제 "저장 취소" API가 정해지면
  // 여기서 호출하고, 취소되면 목록(MOCK_SAVED)에서도 항목을 빼야 한다.
  const [saved, setSaved] = useState(true);

  return (
    <div className="relative flex w-full items-center gap-3 overflow-hidden rounded-[20px] bg-white text-left shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
      {building.thumb ? (
        <img src={building.thumb} alt="" className="h-24 w-24 shrink-0 object-cover" />
      ) : (
        <div
          className="h-24 w-24 shrink-0"
          style={{ background: "linear-gradient(160deg, #e4efe9 0%, #b9d9c7 50%, #7fae93 100%)" }}
        />
      )}
      <div className="min-w-0 flex-1 py-2 pr-10">
        <p className="truncate text-[14px] font-semibold text-[#535353]">{building.title}</p>
        <p className="mt-1 text-[11px] text-[#535353]/70">에너지 절감률</p>
        <p className="text-[18px] font-semibold text-[#176b52]">{Math.round(building.reductionRate * 100)}%</p>
      </div>

      <button
        type="button"
        onClick={() => setSaved((v) => !v)}
        aria-label={saved ? "저장 취소" : "저장"}
        aria-pressed={saved}
        className="absolute right-3 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center"
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill={saved ? "#2fcbaa" : "none"}
          stroke={saved ? "#2fcbaa" : "#B0B0B0"}
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M20.8 4.6c-1.6-1.6-4.2-1.6-5.8 0L12 7.6l-3-3c-1.6-1.6-4.2-1.6-5.8 0-1.6 1.6-1.6 4.2 0 5.8l8.8 8.8 8.8-8.8c1.6-1.6 1.6-4.2 0-5.8Z" />
        </svg>
      </button>
    </div>
  );
}
