import secrets

import bcrypt


def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), password_hash.encode("utf-8"))


def generate_session_token() -> str:
    """JWT가 아닌 opaque 토큰 (PRD v8.1) — 자체 정보를 담지 않고 DB로만 검증한다."""
    return secrets.token_urlsafe(32)
