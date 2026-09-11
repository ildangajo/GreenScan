/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** frontend/.env(.example) — 백엔드 API 베이스 URL. 없으면 client.ts가 http://localhost:8000로 fallback */
  readonly VITE_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
