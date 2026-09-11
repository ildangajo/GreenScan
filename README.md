# GreenScan

노후 단독·다가구주택 및 아파트 대표 공간의 추정 연간 열손실과 그린리모델링 개선 우선순위를 제시하는 사전진단 서비스.

## 구조

- `backend/` — FastAPI 기반 API 서버 (기준 데이터 조회, 사진 일회성 Vision 분석, 계산 엔진)
- `ios/GreenScan/` — iOS(Swift) 클라이언트 (기존 React 웹 클라이언트를 대체)
- `docs/` — PRD, API 명세, ERD, Mock 데이터

## 로컬 실행

처음 clone 받았다면 `.env` 파일을 먼저 준비한다 (`.env`는 gitignore 대상이라 저장소에 없음).

```bash
cp backend/.env.example backend/.env
```

이후 아래 명령으로 DB와 백엔드를 함께 띄운다.

```bash
docker compose up --build
```

iOS 클라이언트는 `ios/GreenScan/project.yml` 기준으로 Xcode에서 별도로 빌드/실행한다.

`backend` 컨테이너는 기동 시 `alembic upgrade head`를 자동 실행해 `docs/db-spec.md` 기준 스키마를 PostgreSQL에 생성한다. 실제 U값/HDD 등 정책 수치는 아직 시드하지 않았으므로 테이블만 만들어진 상태다.

자세한 제품 요구사항은 [docs/prd/GreenScan_PRD_v7.md](docs/prd/GreenScan_PRD_v7.md), DB 설계는 [docs/db-spec.md](docs/db-spec.md) 참고.
