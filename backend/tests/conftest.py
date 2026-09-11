import os

# 테스트는 로컬 .env(실제 DB/API 키)에 의존하지 않는다. 여기서 먼저 값을 정해두면
# pydantic-settings가 .env보다 환경변수를 우선하므로 항상 같은 값으로 테스트된다.
os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://test:test@localhost:5432/test")
os.environ.setdefault("VISION_MODEL", "gpt-5.6-sol")
os.environ.setdefault("OPENAI_API_KEY", "test-key")
os.environ.setdefault("CORS_ALLOW_ORIGINS", "http://localhost:5173")

import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def valid_jpeg_bytes() -> bytes:
    img = Image.new("RGB", (64, 64), color=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()
