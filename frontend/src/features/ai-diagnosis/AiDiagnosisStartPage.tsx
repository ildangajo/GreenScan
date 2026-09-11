import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import layersIcon from "./assets/layers.svg";
import chevronLeftIcon from "./assets/chevron-left.svg";
import chevronDownIcon from "./assets/chevron-down.svg";
import { ApiError } from "../../api/client";
import { geocodeAddress } from "../../api/map";
import { getReferenceOptions } from "../../api/reference";
import type { ConstructionYearRangeOption } from "../../api/types";

/**
 * "AI 분석하기" 시작 화면 — 홈 히어로 배너의 "AI 진단 시작하기"를 누르면 들어오는
 * 새 진입 화면. Figma node 18:141(fileKey FZ0uc815axf5FVAHkuw5Vo)의 정확한
 * 색상/치수/에셋을 그대로 반영했다(#2fcbaa 포인트 컬러, rgba(190,190,190,0.1)
 * 입력창 배경, rgba(47,203,170,0.3) 선택 필 배경 등). 건물 용도에서 "공공"은
 * 요청에 따라 제외했다(Figma엔 있지만 PM 지시로 뺌).
 *
 * 백엔드(2026-09-11 시드 완료) 연동 현황:
 * - 건물 연도: /api/v1/reference/options의 construction_year_ranges를 그대로
 *   쓴다. 지금은 시드가 "2016.07~2023.02"/"2023.02 이후" 두 구간만 있어서
 *   목록이 짧다 — 데이터가 늘면 자동으로 반영된다.
 * - 건물 주소: 입력 후 "확인"을 누르면 /api/v1/map/geocode로 실제 지역을
 *   조회한다. ⚠️ 이 엔드포인트는 로그인이 필요한데(OpenAPI 스키마엔 optional로
 *   보이지만 실제로는 401) 이 브랜치엔 로그인 플로우가 아직 없어서
 *   (feat/fe-auth-login 브랜치 작업 중) 지금은 항상 "로그인이 필요합니다"가
 *   뜬다 — 로그인이 합류하면 바로 동작한다.
 * - 건물 용도(주거/상업업무/기타), 건물 면적(㎡ 구간): reference/options
 *   응답에 대응하는 필드가 아예 없다. 로컬 state로만 유지 — PM/백엔드와
 *   이 두 항목을 뭘로 저장할지 먼저 정해야 한다.
 * - "분석 시작하기": 계산 엔진(POST /api/v1/diagnoses가 요구하는
 *   calculation_result)이 아직 없어서 실제 제출은 TODO로 남겨둔다.
 */

const BUILDING_PURPOSES = ["주거", "상업/업무", "기타"] as const;
const BUILDING_AREAS = ["1,000~2,000㎡", "2,000~4,000㎡", "4,000㎡ 이상"] as const;

type BuildingPurpose = (typeof BUILDING_PURPOSES)[number];
type BuildingArea = (typeof BUILDING_AREAS)[number];

type AddressCheck =
  | { status: "idle" }
  | { status: "checking" }
  | { status: "ok"; regionId: string }
  | { status: "error"; message: string };

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
  const [addressCheck, setAddressCheck] = useState<AddressCheck>({ status: "idle" });
  const [purpose, setPurpose] = useState<BuildingPurpose>("상업/업무");
  const [area, setArea] = useState<BuildingArea>("1,000~2,000㎡");
  const [year, setYear] = useState("");
  const [yearOptions, setYearOptions] = useState<ConstructionYearRangeOption[]>([]);

  useEffect(() => {
    getReferenceOptions()
      .then((res) => setYearOptions(res.construction_year_ranges))
      .catch((err) => console.error("reference/options 조회 실패", err));
  }, []);

  const handlePhotoPick = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files ? Array.from(e.target.files) : [];
    if (files.length > 0) setPhotos(files);
  };

  const handleAddressCheck = async () => {
    if (!address.trim()) return;
    setAddressCheck({ status: "checking" });
    try {
      const res = await geocodeAddress(address.trim());
      setAddressCheck({ status: "ok", regionId: res.region_id });
    } catch (err) {
      const message =
        err instanceof ApiError
          ? ((err.body as { detail?: { message?: string } } | null)?.detail?.message ?? err.message)
          : "주소 확인에 실패했습니다.";
      setAddressCheck({ status: "error", message });
    }
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

        {/* 건물 주소 — "확인" 누르면 실제 지역 조회(/api/v1/map/geocode) */}
        <div className="mt-8 flex flex-col gap-3">
          <label htmlFor="address" className="text-[15px] font-semibold text-[#535353]">
            건물 주소 입력
          </label>
          <div className="flex items-center gap-2 rounded-[20px] bg-white p-[3px] shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]">
            <input
              id="address"
              type="text"
              value={address}
              onChange={(e) => {
                setAddress(e.target.value);
                if (addressCheck.status !== "idle") setAddressCheck({ status: "idle" });
              }}
              onKeyDown={(e) => e.key === "Enter" && handleAddressCheck()}
              placeholder="예) 서울시 마포구 월드컵로 12"
              className="h-[45px] min-w-0 flex-1 rounded-[20px] bg-[rgba(190,190,190,0.1)] px-[9px] text-[15px] font-medium text-[#535353] placeholder:text-[rgba(83,83,83,0.5)] outline-none"
            />
            <button
              type="button"
              onClick={handleAddressCheck}
              disabled={addressCheck.status === "checking" || !address.trim()}
              className="mr-1 shrink-0 rounded-full bg-[#2fcbaa] px-4 py-2 text-[13px] font-semibold text-white disabled:opacity-40"
            >
              {addressCheck.status === "checking" ? "확인 중" : "확인"}
            </button>
          </div>
          {addressCheck.status === "ok" && (
            <p className="text-[12px] font-medium text-[#176b52]">지원 지역 확인됨 ({addressCheck.regionId})</p>
          )}
          {addressCheck.status === "error" && (
            <p className="text-[12px] font-medium text-red-500">{addressCheck.message}</p>
          )}
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
              {yearOptions.map((y) => (
                <option key={y.value} value={y.value}>
                  {y.label}
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
