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
    <main className="auth-page signup-page">
      <header className="auth-page__header">
        <h1>회원가입</h1>
      </header>

      <form className="auth-form" onSubmit={handleSubmit} noValidate>
        <label className="form-field">
          <span>아이디</span>
          <input value={loginId} onChange={(event) => setLoginId(event.target.value)} />
        </label>
        <label className="form-field">
          <span>이름</span>
          <input value={displayName} onChange={(event) => setDisplayName(event.target.value)} />
        </label>
        <label className="form-field">
          <span>비밀번호</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
        </label>
        <label className="form-field">
          <span>비밀번호 확인</span>
          <input
            type="password"
            value={passwordConfirm}
            onChange={(event) => setPasswordConfirm(event.target.value)}
          />
        </label>

        {error && <p className="form-error" role="alert">{error}</p>}

        <button className="primary-button" type="submit" disabled={isSubmitting}>
          {isSubmitting ? "가입 중..." : "회원가입"}
        </button>
      </form>

      <p className="auth-page__link">
        이미 계정이 있으신가요? <Link to="/login">로그인</Link>
      </p>
    </main>
  );
}
