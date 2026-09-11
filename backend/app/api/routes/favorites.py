from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.account import Diagnosis, Favorite, User
from app.schemas.favorite import FavoriteCreateRequest, FavoriteItem, FavoriteListResponse

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.get("", response_model=FavoriteListResponse)
def list_favorites(
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> FavoriteListResponse:
    rows = db.scalars(
        select(Favorite)
        .where(Favorite.user_id == current_user.user_id)
        .order_by(Favorite.created_at.desc())
    ).all()
    return FavoriteListResponse(favorites=[FavoriteItem.model_validate(row) for row in rows])


@router.post("", response_model=FavoriteItem, status_code=201)
def create_favorite(
    payload: FavoriteCreateRequest,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> FavoriteItem:
    """PRD v8.1 2.2절: 저장 탭은 단순 즐겨찾기 토글 — 진단 결과 1건 단위로 가정
    (db-spec.md 9.3, 정책 확정 필요로 남아있던 항목의 잠정 구현)."""
    diagnosis = db.get(Diagnosis, payload.diagnosis_id)
    if diagnosis is None or diagnosis.user_id != current_user.user_id:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "DIAGNOSIS_NOT_FOUND", "message": "즐겨찾기할 진단 기록을 찾을 수 없습니다."},
        )

    favorite = Favorite(
        user_id=current_user.user_id,
        diagnosis_id=diagnosis.diagnosis_id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(favorite)
    db.commit()
    db.refresh(favorite)
    return FavoriteItem.model_validate(favorite)


@router.delete("/{favorite_id}", status_code=204)
def delete_favorite(
    favorite_id: UUID,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
) -> None:
    favorite = db.get(Favorite, favorite_id)
    if favorite is None or favorite.user_id != current_user.user_id:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "FAVORITE_NOT_FOUND", "message": "즐겨찾기를 찾을 수 없습니다."},
        )
    db.delete(favorite)
    db.commit()
