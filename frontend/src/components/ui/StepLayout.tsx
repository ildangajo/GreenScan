import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";

const TOTAL_STEPS = 5;

interface StepLayoutProps {
  /** 1~5. GreenScan MVP 흐름 기준 (건물/공간 선택 → 치수입력 → 사진업로드 → AI확인 → 결과) */
  step: number;
  title: string;
  subtitle?: string;
  children: ReactNode;
  onNext?: () => void;
  onBack?: () => void;
  nextLabel?: string;
  nextDisabled?: boolean;
  hideBack?: boolean;
}

/**
 * 5개 화면이 공유하는 목업 레이아웃 — 상단 진행 표시 + 제목, 하단 이전/다음 내비게이션.
 * 스타일은 최소한(Tailwind 기본 유틸리티)으로만 잡았고, 실제 디자인은 별도 와이어프레임/디자인 산출물을 따른다.
 */
export default function StepLayout({
  step,
  title,
  subtitle,
  children,
  onNext,
  onBack,
  nextLabel = "다음",
  nextDisabled = false,
  hideBack = false,
}: StepLayoutProps) {
  const navigate = useNavigate();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col bg-white">
      <header className="flex flex-col gap-2 border-b border-neutral-200 px-5 pb-3 pt-5">
        <div className="flex gap-1.5">
          {Array.from({ length: TOTAL_STEPS }).map((_, i) => (
            <div
              key={i}
              className={`h-1.5 flex-1 rounded-full ${
                i < step ? "bg-neutral-800" : "bg-neutral-200"
              }`}
            />
          ))}
        </div>
        <p className="text-xs text-neutral-500">
          STEP {step} / {TOTAL_STEPS}
        </p>
        <h1 className="text-xl font-semibold text-neutral-900">{title}</h1>
        {subtitle && <p className="text-sm text-neutral-500">{subtitle}</p>}
      </header>

      <main className="flex-1 overflow-y-auto px-5 py-4">{children}</main>

      <footer className="flex gap-3 border-t border-neutral-200 px-5 py-4">
        {!hideBack && (
          <button
            type="button"
            onClick={onBack ?? (() => navigate(-1))}
            className="flex-1 rounded-lg border border-neutral-300 py-3 text-sm font-medium text-neutral-700"
          >
            이전
          </button>
        )}
        <button
          type="button"
          onClick={onNext}
          disabled={nextDisabled}
          className="flex-[2] rounded-lg bg-neutral-900 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-neutral-300"
        >
          {nextLabel}
        </button>
      </footer>
    </div>
  );
}
