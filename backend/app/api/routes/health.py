"""Liveness and readiness endpoints used by deployment probes."""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.db.session import engine


router = APIRouter(tags=["health"])


@router.get("/health", status_code=status.HTTP_200_OK)
def health_check() -> dict[str, str]:
    """Report that the API process is alive and can receive requests."""
    return {"status": "ok"}


@router.get("/health/ready", status_code=status.HTTP_200_OK)
def readiness_check() -> dict[str, str]:
    """Report whether the configured database accepts a simple query."""
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="database unavailable",
        ) from error

    return {"status": "ready", "database": "connected"}
