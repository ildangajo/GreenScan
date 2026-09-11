import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import layersIcon from "./assets/layers.svg";
import chevronLeftIcon from "./assets/chevron-left.svg";
import chevronDownIcon from "./assets/chevron-down.svg";
import { ApiError } from "../../api/http";
import { geocodeAddress } from "../../api/map";
import { getReferenceOptions, type ConstructionYearRangeOption } from "../../api/reference";
import { useDiagnosis } from "../../state/DiagnosisContext";

/**
 * "AI 분석하기" 시작 화면 — 홈 히어로 배너의 "AI 진단 시작하기"를 누르면 들어오는
 * 진입 화면. Figma node 18:141(fileKey FZ0uc815axf5FVAHkuw5Vo)의 색상/치수/
 * 에셋은 그대로 두되, 필드 구성은 실제 백엔드 계산 계약
 * (backend/app/schemas/diagnosis.py CalculateRequest, api-spec.md 2.4)에
 * 맞춰 다시 짰다.
 *
 * 이전 버전과 달라진 점 (2026-09-11, 백엔드 구조에 맞춤):
 * - "건물 용도"(주거/상업업무/기타)와 "건물 면적"(㎡ 구간) 필드를 없앴다.
 *   계산 API 어디에도 대응하는 항목이 없어서 그동안 저장할 곳 없는 값이었다
 *   — 대신 실제로 계산에 쓰이는 건물유형/대표공간/공간치수/창호/벽체 입력은
 *   기존 5단계 플로우(BuildingSpaceSelectPage → SpaceInputPage →
 *   PhotoUploadPage → AiConfirmPage)가 이미 정확한 스키마로 갖고 있어서,
 *   이 화면은 "사진 + 주소"만 먼저 받고 나머지는 그 플로우로 넘긴다.
 * - 주소를 "확인"하면 얻는 region_id, 선택한 건물 연도(construction_year_range)를
 *   DiagnosisContext에 저장해서 이후 단계(ResultPage의 계산 요청 조립)에서
 *   그대로 쓴다.
 * - 사진은 아직 카테고리별(창호/벽체) 업로드 UI가 없어서 로컬에만 들고
 *   있고 /api/v1/photos/analyze 호출은 PhotoUploadPage 쪽에서 붙일 몫으로
 *   남겨둔다(그 화면은 이미 창호/벽체 슬롯을 구분해서 갖고 있다).
 */

type AddressCheck =
  | { status: "idle" }
  | { status: "checking" }
  | { status: "ok"; regionId: string }
  | { status: "error"; message: string };

export default function AiDiagnosisStartPage() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { state, update } = useDiagnosis();

  const [photos, setPhotos] = useState<File[]>([]);
  const [address, setAddress] = useState(state.address);
  const [addressCheck, setAddressCheck] = useState<AddressCheck>(
    state.regionId ? { status: "ok", regionId: state.regionId } : { status: "idle" },
  );
  const [year, setYear] = useState(state.constructionYearRange);
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
      update({ address: address.trim(), regionId: res.region_id });
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "주소 확인에 실패했습니다.";
      setAddressCheck({ status: "error", message });
    }
  };

  const canProceed = addressCheck.status === "ok" && year !== "";

  const handleStart = () => {
    update({ constructionYearRange: year });
    // 나머지(건물유형/대표공간/공간치수/창호/벽체)는 기존 5단계 플로우에서 이어받는다.
    navigate("/start");
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
        {/* 사진 업로드 카드 — 실제 분석 호출은 다음 단계(사진 업로드 화면)에서 창호/벽체로 나눠서 한다 */}
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

        {/* 건물 주소 — "확인" 누르면 실제 지역 조회(/api/v1/map/geocode), 성공 시 region_id를 DiagnosisContext에 저장 */}
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

        {/* 건물 연도 — construction_year_range로 그대로 계산 요청에 쓰인다 */}
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

        <p className="mt-6 rounded-[16px] border border-dashed border-[rgba(83,83,83,0.3)] px-4 py-3 text-[12px] leading-relaxed text-[#535353]/70">
          건물유형·대표공간·공간 치수·창호·벽체 정보는 다음 화면들에서 이어서 입력합니다.
        </p>
      </main>

      {/* 분석 시작하기 — 기존 5단계 플로우(건물유형 선택)로 이어간다. 계산 자체는 그 플로우 끝(ResultPage)에서 실행된다 */}
      <div className="flex shrink-0 justify-center px-[21px] py-4">
        <button
          type="button"
          onClick={handleStart}
          disabled={!canProceed}
          className="rounded-[50px] bg-[#2fcbaa] px-[62px] py-[13px] text-[15px] font-semibold text-white disabled:opacity-40"
        >
          분석 시작하기
        </button>
      </div>
    </div>
  );
}
