"""Liveness endpoint used by deployment probes."""

from typing import Literal

from fastapi import APIRouter, HTTPException, status
from pydantic import ValidationError
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import Settings


router = APIRouter(tags=["health"])


@router.get("/health", status_code=status.HTTP_200_OK)
def health_check() -> dict[str, Literal["ok"]]:
    """Report that the API process is alive and can receive requests."""
    return {"status": "ok"}


@router.get("/health/db", status_code=status.HTTP_200_OK)
def database_health_check() -> dict[str, Literal["ok", "connected"]]:
    """Report whether the configured database accepts a simple query."""
    try:
        database_url = Settings().database_url
    except ValidationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "error", "database": "not_configured"},
        ) from error

    try:
        engine = create_engine(database_url, pool_pre_ping=True)
    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "error", "database": "unavailable"},
        ) from error

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "error", "database": "unavailable"},
        ) from error
    finally:
        engine.dispose()

    return {"status": "ok", "database": "connected"}
