from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.api.deps import get_current_session
from app.core.config import settings
from app.core.security import generate_session_token, verify_password
from app.db.session import get_db
from app.models.account import Session as SessionModel, User
from app.schemas.auth import LoginRequest, LoginResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: DbSession = Depends(get_db)) -> LoginResponse:
    """DB에 시드된 계정으로만 로그인한다 — 자체 회원가입 플로우는 없다 (PRD v8.1)."""
    user = db.scalar(select(User).where(User.login_id == payload.login_id))

    # 계정 존재 여부를 응답 시간/메시지로 흘리지 않기 위해 동일한 오류로 처리한다.
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail={"error_code": "INVALID_CREDENTIALS", "message": "로그인 정보가 올바르지 않습니다."},
        )

    token = generate_session_token()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.session_ttl_hours)
    db.add(SessionModel(session_token=token, user_id=user.user_id, expires_at=expires_at))
    db.commit()

    return LoginResponse(session_token=token, expires_at=expires_at, display_name=user.display_name)


@router.post("/logout", status_code=204)
def logout(
    current_session: SessionModel = Depends(get_current_session),
    db: DbSession = Depends(get_db),
) -> None:
    db.delete(current_session)
    db.commit()
