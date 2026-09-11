from datetime import datetime

from pydantic import BaseModel


class LoginRequest(BaseModel):
    login_id: str
    password: str


class LoginResponse(BaseModel):
    session_token: str
    expires_at: datetime
    display_name: str | None = None
