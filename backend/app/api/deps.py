from datetime import datetime, timezone

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session as DbSession

from app.db.session import get_db
from app.models.account import Session as SessionModel, User


def get_current_session(
    authorization: str | None = Header(default=None),
    db: DbSession = Depends(get_db),
) -> SessionModel:
    """`Authorization: Bearer <opaque session token>` 헤더의 세션을 검증한다.

    JWT가 아니므로 토큰 자체에는 정보가 없다 — 매 요청마다 DB의 sessions 테이블을
    조회해 유효성과 만료 여부를 검증한다 (PRD v8.1).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail={"error_code": "UNAUTHORIZED", "message": "로그인이 필요합니다."},
        )

    token = authorization.removeprefix("Bearer ").strip()
    session = db.get(SessionModel, token)
    if session is None:
        raise HTTPException(
            status_code=401,
            detail={"error_code": "SESSION_INVALID", "message": "세션이 유효하지 않습니다."},
        )

    if session.expires_at < datetime.now(timezone.utc):
        db.delete(session)
        db.commit()
        raise HTTPException(
            status_code=401,
            detail={"error_code": "SESSION_EXPIRED", "message": "세션이 만료되었습니다. 다시 로그인해주세요."},
        )

    return session


def get_current_user(
    session: SessionModel = Depends(get_current_session),
    db: DbSession = Depends(get_db),
) -> User:
    user = db.get(User, session.user_id)
    if user is None:
        raise HTTPException(
            status_code=401,
            detail={"error_code": "SESSION_INVALID", "message": "세션이 유효하지 않습니다."},
        )
    return user
