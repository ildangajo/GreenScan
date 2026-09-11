"""Deployment-time database connectivity check."""

import os

import pytest
from sqlalchemy import create_engine, text


def test_database_connection() -> None:
    """Verify the configured database accepts a simple query during deployment."""
    if os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true":
        pytest.skip("Set RUN_DB_CONNECTION_TEST=true to run the deployment DB check.")

    database_url = os.getenv("DATABASE_URL")
    assert database_url, "DATABASE_URL must be set for the deployment DB check."

    engine = create_engine(database_url, pool_pre_ping=True)
    try:
        with engine.connect() as connection:
            assert connection.execute(text("SELECT 1")).scalar_one() == 1
    finally:
        engine.dispose()
