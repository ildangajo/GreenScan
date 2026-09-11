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
    <main className="auth-page login-page">
      <header className="auth-page__header">
        <h1>로그인</h1>
      </header>

      <form className="auth-form" onSubmit={handleSubmit} noValidate>
        <label className="form-field">
          <span>아이디</span>
          <input
            name="loginId"
            autoComplete="username"
            value={loginId}
            onChange={(event) => setLoginId(event.target.value)}
            placeholder="아이디를 입력해주세요"
          />
        </label>

        <label className="form-field">
          <span>비밀번호</span>
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="비밀번호를 입력해주세요"
          />
        </label>

        {error && <p className="form-error" role="alert">{error}</p>}

        <button className="primary-button" type="submit" disabled={isSubmitting}>
          {isSubmitting ? "로그인 중..." : "로그인"}
        </button>
      </form>

      <p className="auth-page__link">
        계정이 없으신가요? <Link to="/signup">회원가입</Link>
      </p>
    </main>
  );
}
