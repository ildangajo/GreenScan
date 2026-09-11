"""db-spec.md 9장(v8.1): 계정·세션·진단이력·즐겨찾기.

0~8장의 기준 데이터 테이블과 달리, 이 영역은 사용자별 상태를 저장하는 순수
애플리케이션 스키마다. 사진 원본·AI 원본 응답·등급/레벨/견적은 어떤 필드로도
저장하지 않는다 (db-spec.md 1.2, 9장).
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # 자체 가입 플로우 없음 — 운영자가 미리 시드한 소수 계정만 사용 (PRD v8.1).
    login_id: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Session(Base):
    __tablename__ = "sessions"

    # JWT 미사용 — 서버가 발급하고 DB로 검증하는 opaque 토큰 (PRD v8.1, api-spec.md 0.2).
    session_token: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Diagnosis(Base):
    __tablename__ = "diagnoses"

    diagnosis_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    building_type_key: Mapped[str] = mapped_column(String, nullable=False)
    region_id: Mapped[str] = mapped_column(String, nullable=False)
    # 사용자 확정 공간/창호/벽체 입력. 원본 사진은 포함하지 않는다.
    confirmed_input: Mapped[dict] = mapped_column(JSONB, nullable=False)
    # 기준선·시나리오·우선순위 스냅샷. 이후 기준 데이터가 바뀌어도 과거 이력은
    # 이 스냅샷 그대로 유지된다 (db-spec.md 9.2 — 의도적으로 정규화하지 않음).
    calculation_result: Mapped[dict] = mapped_column(JSONB, nullable=False)
    calculation_version: Mapped[str] = mapped_column(String, nullable=False)
    reference_data_version: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Favorite(Base):
    __tablename__ = "favorites"

    favorite_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    # 진단 결과 1건 단위로 가정 (db-spec.md 9.3 — 정책 확정 필요로 남아있는 항목).
    diagnosis_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("diagnoses.diagnosis_id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
