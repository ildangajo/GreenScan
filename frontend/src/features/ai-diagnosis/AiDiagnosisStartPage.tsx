import { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import layersIcon from "./assets/layers.svg";
import chevronLeftIcon from "./assets/chevron-left.svg";
import chevronDownIcon from "./assets/chevron-down.svg";

/**
 * "AI 분석하기" 시작 화면 — 홈 히어로 배너의 "AI 진단 시작하기"를 누르면 들어오는
 * 새 진입 화면. Figma node 18:141(fileKey FZ0uc815axf5FVAHkuw5Vo)의 정확한
 * 색상/치수/에셋을 그대로 반영했다(#2fcbaa 포인트 컬러, rgba(190,190,190,0.1)
 * 입력창 배경, rgba(47,203,170,0.3) 선택 필 배경 등). 건물 용도에서 "공공"은
 * 요청에 따라 제외했다(Figma엔 있지만 PM 지시로 뺌).
 *
 * 주의:
 * - 기존 5단계 MVP 플로우(features/space-input, features/vision-analysis)와는
 *   아직 데이터로 연결돼 있지 않다. 이 화면의 필드(주소/용도/면적/연도/사진)는
 *   기존 DiagnosisContext 스키마(건물유형/공간유형/치수 등)와 항목이 달라서,
 *   PM이 두 플로우의 관계(이 화면이 기존 1단계를 대체하는지, 별도 화면인지)를
 *   확정하기 전까지는 로컬 state로만 값을 들고 있고 "분석 시작하기"는 실제
 *   제출/다음 화면 연결 없이 TODO로 남겨둔다.
 * - 라우팅도 같은 이유로 /start 를 그대로 가리키게 하지 않고 별도 경로
 *   (/ai-diagnosis)로 붙였다. 기존 /start(건물유형 선택) 화면은 그대로 살아있다.
 */

const BUILDING_PURPOSES = ["주거", "상업/업무", "기타"] as const;
const BUILDING_AREAS = ["1,000~2,000㎡", "2,000~4,000㎡", "4,000㎡ 이상"] as const;
const BUILDING_YEARS = Array.from({ length: 46 }, (_, i) => `${2025 - i}년`);

type BuildingPurpose = (typeof BUILDING_PURPOSES)[number];
type BuildingArea = (typeof BUILDING_AREAS)[number];

/** 선택형 필(pill) 버튼 — 선택 시 배경만 teal 톤으로 바뀌고 글자색은 그대로(#535353) 유지된다 */
function PillOption({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`shrink-0 rounded-[30px] px-[10px] py-[10px] text-[12px] font-semibold text-[#535353] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.2)] ${
        selected ? "bg-[rgba(47,203,170,0.3)]" : "bg-white"
      }`}
    >
      {label}
    </button>
  );
}

export default function AiDiagnosisStartPage() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [photos, setPhotos] = useState<File[]>([]);
  const [address, setAddress] = useState("");
  const [purpose, setPurpose] = useState<BuildingPurpose>("상업/업무");
  const [area, setArea] = useState<BuildingArea>("1,000~2,000㎡");
  const [year, setYear] = useState("");

  const handlePhotoPick = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files ? Array.from(e.target.files) : [];
    if (files.length > 0) setPhotos(files);
  };

  return (
    <div className="relative mx-auto flex h-screen w-full max-w-md flex-col overflow-hidden bg-white">
      {/* 상단 헤더 — 뒤로가기 + 제목 */}
      <header className="flex shrink-0 items-center gap-[21px] px-[21px] pb-3 pt-5">
        <button type="button" onClick={() => navigate(-1)} aria-label="뒤로가기" className="shrink-0">
          <img src={chevronLeftIcon} alt="" className="h-6 w-6" />
        </button>
        <h1 className="text-[18px] font-normal text-[#535353]">AI 분석하기</h1>
      </header>

      <main className="min-h-0 flex-1 overflow-y-auto px-[21px] pb-28">
        {/* 사진 업로드 카드 */}
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="flex w-full flex-col items-center gap-[10px] rounded-[20px] bg-white px-[38px] py-[27px] text-center shadow-[0px_2px_8px_0px_rgba(0,0,0,0.3)]"
        >
          <span className="flex h-[53px] w-[53px] items-center justify-center rounded-full bg-[#2fcbaa]">
            <img src={layersIcon} alt="" className="h-6 w-6" />
          </span>
          <p className="text-[14px] font-semibold text-[#535353]">사진</p>
          <p className="text-[12px] font-normal text-[#535353]">
            {photos.length > 0 ? `${photos.length}장 선택됨` : "창호,천장,벽 등을 업로드 해주세요"}
          </p>
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          onChange={handlePhotoPick}
          className="hidden"
        />

        {/* 안내 문구 + 진행 점(세로 2개) */}
        <div className="mt-8 flex items-start gap-4">
          <p className="text-[20px] leading-normal text-[#535353]">
            <span className="font-extrabold">건물 정보를 입력하면</span>
            <br />
            AI 맞춤 서비스가 시작됩니다.
          </p>
          <div className="mt-2 flex shrink-0 flex-col gap-[6px] pt-1">
            <span className="h-[10px] w-[10px] rounded-full bg-[rgba(23,107,82,0.5)]" />
            <span className="h-[10px] w-[10px] rounded-full bg-[rgba(23,107,82,0.8)]" />
          </div>
        </div>

        {/* 건물 주소 */}
        <div className="mt-8 flex flex-col gap-3">
          <label htmlFor="address" className="text-[15px] font-semibold text-[#535353]">
            건물 주소 입력
          </label>
          <div className="rounded-[20px] bg-white p-[3px] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
            <input
              id="address"
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="예) 서울시 마포구 월드컵로 12"
              className="h-[45px] w-full rounded-[20px] bg-[rgba(190,190,190,0.1)] px-[9px] text-[15px] font-medium text-[#535353] placeholder:text-[rgba(83,83,83,0.5)] outline-none"
            />
          </div>
        </div>

        {/* 건물 용도 */}
        <div className="mt-6 flex flex-col gap-3">
          <span className="text-[15px] font-semibold text-[#535353]">건물 용도</span>
          <div className="flex flex-wrap gap-[14px]">
            {BUILDING_PURPOSES.map((option) => (
              <PillOption key={option} label={option} selected={purpose === option} onClick={() => setPurpose(option)} />
            ))}
          </div>
        </div>

        {/* 건물 면적 */}
        <div className="mt-6 flex flex-col gap-3">
          <span className="text-[15px] font-semibold text-[#535353]">건물 면적</span>
          <div className="flex flex-wrap gap-[14px]">
            {BUILDING_AREAS.map((option) => (
              <PillOption key={option} label={option} selected={area === option} onClick={() => setArea(option)} />
            ))}
          </div>
        </div>

        {/* 건물 연도 */}
        <div className="mt-6 flex flex-col gap-3">
          <label htmlFor="year" className="text-[15px] font-semibold text-[#535353]">
            건물 연도
          </label>
          <div className="relative rounded-[20px] bg-white p-[3px] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
            <select
              id="year"
              value={year}
              onChange={(e) => setYear(e.target.value)}
              className="h-[45px] w-full appearance-none rounded-[20px] bg-[rgba(190,190,190,0.1)] px-[9px] text-[15px] font-medium text-[#535353] outline-none"
            >
              <option value="" disabled className="text-[rgba(83,83,83,0.5)]">
                선택해주세요
              </option>
              {BUILDING_YEARS.map((y) => (
                <option key={y} value={y}>
                  {y}
                </option>
              ))}
            </select>
            <img src={chevronDownIcon} alt="" className="pointer-events-none absolute right-[16px] top-1/2 h-2 w-3.5 -translate-y-1/2" />
          </div>
        </div>
      </main>

      {/* 분석 시작하기 — 실제 제출/다음 화면 연결은 TODO */}
      <div className="flex shrink-0 justify-center px-[21px] py-4">
        <button
          type="button"
          // TODO: 기존 5단계 플로우와의 연결 방식이 정해지면 여기서 다음 화면으로 이동
          onClick={() => navigate("/space-input")}
          className="rounded-[50px] bg-[#2fcbaa] px-[62px] py-[13px] text-[15px] font-semibold text-white"
        >
          분석 시작하기
        </button>
      </div>
    </div>
  );
}
