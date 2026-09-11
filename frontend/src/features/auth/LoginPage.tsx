import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import { ApiError } from "../../api/http";
import { login } from "../../api/auth";

export default function LoginPage() {
  const navigate = useNavigate();
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if (!loginId.trim() || !password) {
      setError("아이디와 비밀번호를 모두 입력해주세요.");
      return;
    }

    setIsSubmitting(true);
    try {
      await login({ login_id: loginId.trim(), password });
      navigate("/mypage");
    } catch (caught) {
      setError(caught instanceof ApiError ? caught.message : "로그인에 실패했습니다.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center bg-white px-6 py-10">
      <header className="mb-8">
        <h1 className="text-2xl font-bold text-neutral-900">로그인</h1>
      </header>

      <form className="flex flex-col gap-4" onSubmit={handleSubmit} noValidate>
        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>아이디</span>
          <input
            name="loginId"
            autoComplete="username"
            value={loginId}
            onChange={(event) => setLoginId(event.target.value)}
            placeholder="아이디를 입력해주세요"
            className="rounded-xl border border-neutral-200 px-4 py-3 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:border-brand-400 focus:ring-1 focus:ring-brand-400"
          />
        </label>

        <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-700">
          <span>비밀번호</span>
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="비밀번호를 입력해주세요"
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
          {isSubmitting ? "로그인 중..." : "로그인"}
        </button>
      </form>

      <p className="mt-6 text-center text-sm text-neutral-500">
        계정이 없으신가요?{" "}
        <Link to="/signup" className="font-semibold text-brand-600">
          회원가입
        </Link>
      </p>
    </main>
  );
}
