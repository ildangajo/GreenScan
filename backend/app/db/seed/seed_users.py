"""데모 계정 시드 스크립트.

자체 회원가입 플로우가 없으므로(PRD v8.1, db-spec.md 9장), 로그인 가능한
계정은 이 스크립트로만 만든다. 평문 자격증명을 저장소에 커밋하지 않도록
SEED_USER_LOGIN_ID / SEED_USER_PASSWORD 환경변수로 받는다.

실행: python -m app.db.seed.seed_users
"""

import sys
from datetime import datetime, timezone

from sqlalchemy import select

from app.core.config import settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.account import User


def seed_users() -> None:
    if not settings.seed_user_login_id or not settings.seed_user_password:
        print("SEED_USER_LOGIN_ID / SEED_USER_PASSWORD가 설정되지 않아 계정을 만들지 않습니다.")
        sys.exit(1)

    db = SessionLocal()
    try:
        existing = db.scalar(select(User).where(User.login_id == settings.seed_user_login_id))
        if existing is not None:
            print(f"이미 존재하는 계정입니다: {settings.seed_user_login_id}")
            return

        user = User(
            login_id=settings.seed_user_login_id,
            password_hash=hash_password(settings.seed_user_password),
            created_at=datetime.now(timezone.utc),
        )
        db.add(user)
        db.commit()
        print(f"계정을 생성했습니다: {settings.seed_user_login_id}")
    finally:
        db.close()


if __name__ == "__main__":
    seed_users()
