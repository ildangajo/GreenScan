from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    vision_model: str = ""
    openai_api_key: str = ""
    cors_allow_origins: str = "http://localhost:5173"
    # PRD v8.1 / db-spec.md 9.3: 세션 TTL 정책 확정 필요 — 24시간을 기본값으로 잠정 채택.
    session_ttl_hours: int = 24
    # 자체 가입 없음(db-spec.md 9장) — 최초 배포 시 시드할 데모 계정 자격증명.
    seed_user_login_id: str = ""
    seed_user_password: str = ""
    # 지도 검색(카카오맵) 서버 사이드 지오코딩용 — REST API Key만 백엔드에 둔다.
    # JavaScript Key는 프론트 전용이라 여기서 관리하지 않는다.
    kakao_rest_api_key: str = ""


settings = Settings()
