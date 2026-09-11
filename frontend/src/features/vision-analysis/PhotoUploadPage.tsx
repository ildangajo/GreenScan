import { useState } from "react";
import { useNavigate } from "react-router-dom";
import StepLayout from "../../components/ui/StepLayout";

/**
 * 화면 3: 창호/벽체 사진 업로드.
 * 목업 단계라 실제 업로드나 블러 체크는 붙이지 않고 선택된 파일명만 표시한다.
 * 실제 연동 시 POST /api/v1/photos/analyze (docs/api-design.md 2.3, 5.0절)로 대체.
 */
export default function PhotoUploadPage() {
  const navigate = useNavigate();
  const [windowPhotoName, setWindowPhotoName] = useState<string | null>(null);
  const [wallPhotoName, setWallPhotoName] = useState<string | null>(null);

  return (
    <StepLayout
      step={3}
      title="창호와 벽체 사진을 올려주세요"
      subtitle="사진 없이도 다음 단계에서 수동 선택으로 진행할 수 있습니다"
      onNext={() => navigate("/ai-confirm")}
      onBack={() => navigate("/space-input")}
    >
      <div className="flex flex-col gap-5">
        <UploadSlot label="창호 사진" fileName={windowPhotoName} onSelect={setWindowPhotoName} />
        <UploadSlot label="벽체 사진" fileName={wallPhotoName} onSelect={setWallPhotoName} />

        <div className="rounded-lg border border-neutral-200 p-3">
          <p className="mb-2 text-sm font-semibold">촬영 가이드</p>
          <ul className="flex flex-col gap-1 text-xs text-neutral-600">
            <li>— 창호는 프레임과 유리면이 함께 보이게 찍어주세요</li>
            <li>— 벽체는 의심 부위가 흐리지 않게 가까이서 찍어주세요</li>
            <li>— 어두움, 강한 반사, 원거리 촬영은 재촬영 대상입니다</li>
          </ul>
        </div>

        <p className="text-xs text-neutral-400">
          업로드한 사진은 AI 분석을 위해 외부 API로 전송되며, GreenScan 서버에는 원본이 저장되지 않습니다.
        </p>
      </div>
    </StepLayout>
  );
}

function UploadSlot({
  label,
  fileName,
  onSelect,
}: {
  label: string;
  fileName: string | null;
  onSelect: (name: string) => void;
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <span className="text-sm font-semibold">{label}</span>
        {fileName && (
          <span className="rounded-full bg-green-50 px-2 py-0.5 text-[11px] font-medium text-green-700">
            업로드 완료
          </span>
        )}
      </div>
      <label className="flex h-32 cursor-pointer flex-col items-center justify-center gap-1 rounded-lg border-2 border-dashed border-neutral-300 text-xs text-neutral-500">
        <span>{fileName ?? "탭하여 촬영 또는 선택"}</span>
        <input
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) onSelect(file.name);
          }}
        />
      </label>
    </div>
  );
}
