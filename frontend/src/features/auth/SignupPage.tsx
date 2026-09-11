import { FormEvent, useState } from "react";
import { Link } from "react-router-dom";

export interface SignupValues {
  loginId: string;
  displayName: string;
  password: string;
}

interface SignupPageProps {
  onSignup?: (values: SignupValues) => Promise<void>;
}

export default function SignupPage({ onSignup }: SignupPageProps) {
  const [loginId, setLoginId] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if (!loginId.trim() || !displayName.trim() || !password || !passwordConfirm) {
      setError("모든 항목을 입력해주세요.");
      return;
    }
    if (password !== passwordConfirm) {
      setError("비밀번호가 일치하지 않습니다.");
      return;
    }
    if (!onSignup) {
      setError("회원가입 API가 아직 준비되지 않았습니다.");
      return;
    }

    setIsSubmitting(true);
    try {
      await onSignup({ loginId: loginId.trim(), displayName: displayName.trim(), password });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "회원가입에 실패했습니다.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center bg-white px-6 py-10">
      <header className="mb-8">
        <h1 className="text-2xl font-bold text-neutral-900">회원가입</h1>
      </header>

      <form className="flex flex-col gap-4" onSubmit={handleSubmit} noValidate>
        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>아이디</span>
          <input
            value={loginId}
            onChange={(event) => setLoginId(event.target.value)}
            placeholder="아이디를 입력해주세요"
            className="rounded-xl border border-neutral-200 px-4 py-3 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:border-brand-400 focus:ring-1 focus:ring-brand-400"
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>이름</span>
          <input
            value={displayName}
            onChange={(event) => setDisplayName(event.target.value)}
            placeholder="이름을 입력해주세요"
            className="rounded-xl border border-neutral-200 px-4 py-3 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:border-brand-400 focus:ring-1 focus:ring-brand-400"
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>비밀번호</span>
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="비밀번호를 입력해주세요"
            className="rounded-xl border border-neutral-200 px-4 py-3 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:border-brand-400 focus:ring-1 focus:ring-brand-400"
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>비밀번호 확인</span>
          <input
            type="password"
            value={passwordConfirm}
            onChange={(event) => setPasswordConfirm(event.target.value)}
            placeholder="비밀번호를 다시 입력해주세요"
            className="rounded-xl border border-neutral-200 px-4 py-3 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:border-brand-400 focus:ring-1 focus:ring-brand-400"
          />
        </label>

        {error && (
          <p className="text-sm font-medium text-red-500" role="alert">
            {error}
          </p>
        )}

        <button
          className="mt-2 rounded-xl bg-brand-400 py-3.5 text-sm font-semibold text-white shadow-lg shadow-brand-400/30 disabled:opacity-60"
          type="submit"
          disabled={isSubmitting}
        >
          {isSubmitting ? "가입 중..." : "회원가입"}
        </button>
      </form>

      <p className="mt-6 text-center text-sm text-neutral-500">
        이미 계정이 있으신가요?{" "}
        <Link to="/login" className="font-semibold text-brand-600">
          로그인
        </Link>
      </p>
    </main>
  );
}
