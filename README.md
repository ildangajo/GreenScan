# GreenScan

노후 단독·다가구주택 및 아파트 대표 공간의 추정 연간 열손실과 그린리모델링 개선 우선순위를 제시하는 사전진단 서비스.

## 구조

- `backend/` — FastAPI 기반 API 서버 (기준 데이터 조회, 사진 일회성 Vision 분석, 계산 엔진)
- `frontend/` — React + Vite 웹 클라이언트
- `docs/` — PRD, API 명세, ERD, Mock 데이터

## 로컬 실행

```bash
docker compose up --build
```

자세한 제품 요구사항은 [docs/prd/GreenScan_PRD_v7.md](docs/prd/GreenScan_PRD_v7.md) 참고.
