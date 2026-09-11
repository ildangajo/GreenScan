# GreenScan API 설계 v1

- 기준 문서: `GreenScan PRD Agent Directive v7` (사진 Vision 기반)
- 작성 브랜치: `geon0814/api-design` (base: `feat/BE`)
- 상태: 초안 — BE-A/BE-B/BE-C 리뷰 필요, "정책 확정 필요" 표시된 값은 임의로 확정하지 않음

이 문서는 PRD v7의 9장(API/DB 설계 지시), 13장(에이전트 산출물 요구) 중 **API 설계 관련 항목**만 다룬다. DB ERD/DBML은 별도 문서에서 다룬다.

> **⚠️ v8.1 반영 필요 (2026-09-11, BE-A 담당자가 PM과 직접 확인)**: PRD가 v8/v8.1로 갱신되면서 아래 항목이 이 문서의 v7 기준 내용을 대체한다. 상세 근거는 `docs/prd/GreenScan_PRD_v8 (1).md`의 "v8.1 수정" 공지 참고.
> - **로그인/계정 도입** — 0절의 "로그인 없음" 전제는 더 이상 유효하지 않다. JWT 미사용, DB에 미리 시드한 소수 계정만 사용(자체 가입/소셜 로그인 없음).
> - **진단 이력 저장** — 로그인한 사용자의 입력값/확정값/계산 결과는 계정에 귀속되어 저장된다(원본 사진은 여전히 저장 안 함). 0.3절의 "제외" 판단은 폐기.
> - **즐겨찾기** — 단순 토글 기능 추가.
> - **지도 검색** — 카카오맵 연동, 서울 지역만 지원.
> - **등급/레벨/견적 표시는 넣지 않는다** (v8이 조건부 허용했다가 v8.1에서 재철회).
> - 아래 0~9장 본문은 아직 v7 기준 그대로이며, 신규 API(인증/이력/즐겨찾기/지역판별)는 1.1절에 추가로 정리한다. 기존 계산/사진분석 API 계약은 변경 없음.

---

## 0. 전제와 원칙 (PRD 재확인)

- 로그인 없음. 서버는 진단 이력을 저장하지 않는다. 모든 API는 요청→즉시 응답 방식이며 세션 상태를 서버에 두지 않는다.
- 사진 원본은 어떤 API에서도 영구 저장하지 않는다. `POST /photos/analyze` 처리가 끝나면 서버 메모리/임시파일은 즉시 폐기한다.
- 계산은 서버(BE-C 계산 엔진)만 수행한다. 프론트는 계산식을 갖지 않는다.
- AI 후보값은 계산 입력이 될 수 없다. 계산 API는 **사용자 확정값**만 받는다.
- 기준 데이터가 없으면 임의 수치를 만들지 않고 `REFERENCE_DATA_MISSING` 오류로 계산을 중단한다.
- 프론트는 AI API 키와 U값 테이블 전체를 갖지 않는다.

## 0.1 확정된 정책값 (이번 설계에 바로 적용)

- Vision 제공자: **OpenAI로 최종 확정**. 호출 방식은 **OpenAI 파이썬 SDK 사용으로 재확정**(2026-09-11, PM 합의) — 기존에 검토했던 "범용 HTTP(requests) 직접 호출, provider SDK 강결합 금지" 방침은 철회한다. 최종 제출 기준 제공자가 OpenAI 하나로 고정되는 이상 SDK가 주는 안정성·유지보수 이점이 provider 교체 가능성보다 우선한다고 판단했다. 모델명은 `VISION_MODEL` 환경변수로 관리해 모델 버전 교체 여지는 유지한다.
- MVP 지원 지역: `seoul`(서울특별시), `gimpo`(경기도 김포시) — 둘 다 기후구역 `central-1`(중부1지역), 같은 HDD 값 사용.
- `floor_area_m2`: 계산에 사용하지 않음. 가로×세로 크로스체크 + 향후 바닥/지붕 확장용 저장 필드.
- `wall.insulation_status`: 입력만 받고 이번 계산에는 사용하지 않음(향후 확장용 저장 필드). 벽체 현재 추정 U값은 `construction_year_range`만으로 조회.
- **원본 사진 저장 여부: 저장 안 함으로 재확정.** 게스트 세션+S3 저장 방식 검토가 있었으나(2026-09-11), 최종적으로 PRD v7 원칙대로 무상태·원본 즉시 폐기 유지로 확정. 아래 0.3 참고.
- **사진 1장 최대 용량: 10MB로 확정.** (2026-09-11, BE-B) `POST /photos/analyze`는 이 값을 넘으면 `PHOTO_TOO_LARGE`(400)로 즉시 거부한다.

## 0.3 (폐기됨 — v8.1) 향후 확장 메모였던 항목, 이제 Must로 확정

~~"회원이 과거 진단 기록을 조회할 수 있게" 하는 기능이 향후 검토될 수 있다는 의견이 있었음...~~ **v8.1(2026-09-11)에서 확정: 계정/로그인/진단 이력 저장을 이번 범위에 포함한다.** 상세는 1.1절 신규 API, `docs/db-spec.md`의 계정/이력 테이블 참고.

## 0.2 공통 규칙

| 항목 | 규칙 |
|---|---|
| Base path | `/api/v1` |
| 인증 | **(v8.1) 로그인 필요.** JWT 미사용 — 서버 세션/DB에 저장된 opaque 토큰 기반. `Authorization` 헤더 또는 세션 쿠키로 전달(BE-A 구현 시 확정). 로그인 API 외 인증 필요 엔드포인트는 1.1절 참고 |
| Content-Type | JSON, 사진 업로드만 `multipart/form-data` |
| 단위 | 길이 m, 면적 m², U값 W/m²·K, HDD K·day, 열손실 kWh/year |
| 응답 공통 필드 | 계산 관련 응답에는 `calculation_version`, `reference_data_version` 포함 |
| 오류 응답 포맷 | `{ "error_code": "STRING", "message": "사용자용 한국어 메시지", "detail": { ... } }` |
| 타임아웃 | Vision 호출 포함 API는 동기 처리. FastAPI 쪽 타임아웃 권장값은 BE-B 확인 필요 (정책 확정 필요) |

---

## 1. API 목록 개요

| 그룹 | Method | Path | 책임 | Must/Should |
|---|---|---|---|---|
| 기준 데이터 조회 | GET | `/api/v1/regions` | 지원 지역 목록 + HDD 조회키 | Must |
| 기준 데이터 조회 | GET | `/api/v1/reference/options` | 입력 폼에 필요한 선택지(enum/정책값) 조회 | Must |
| 사진 분석 | POST | `/api/v1/photos/analyze` | 사진 1장 일회성 Vision 분석, 원본 미저장 | Must |
| 계산 | POST | `/api/v1/diagnoses/calculate` | 확정 입력으로 열손실 계산 + 시나리오 반환 | Must |
| 고지서 참고 비교 | POST | `/api/v1/bills/compare` | 선택 고지서 참고 비교 (핵심 계산 보정 아님) | Should |

프론트가 실제로 쓰는 순서(PRD 9.1 권장 흐름과 동일):

```
1. GET /regions, GET /reference/options   → 입력 폼 구성
2. POST /photos/analyze (window, wall 각 1회 이상 가능) → AI 후보 표시 → 사용자 확인/수정/확정
3. POST /diagnoses/calculate (확정값 일괄 전달) → 결과 표시
4. (선택) POST /bills/compare
```

### 1.1 (v8.1 신규) 인증·이력·즐겨찾기·지도 API

세부 요청/응답 DTO는 미설계 — 아래는 그룹·책임·인증 필요 여부만 정리한 개요다. BE-A가 구현하며 db-spec.md의 계정/이력 테이블 설계와 짝을 맞춘다.

| 그룹 | Method | Path (안) | 책임 | 인증 필요 |
|---|---|---|---|---|
| 인증 | POST | `/api/v1/auth/login` | DB에 시드된 계정으로 로그인, 세션 토큰(비-JWT) 발급 | N |
| 인증 | POST | `/api/v1/auth/logout` | 세션 토큰 무효화 | Y |
| 진단 이력 | GET | `/api/v1/diagnoses` | 로그인 계정에 귀속된 과거 진단 목록 조회 | Y |
| 진단 이력 | GET | `/api/v1/diagnoses/{id}` | 진단 상세 조회 (원본 사진 제외, 확정 입력·계산 결과만) | Y |
| 진단 이력 | POST | `/api/v1/diagnoses/{id}/save` 또는 계산 응답에 자동 저장 | `diagnoses/calculate` 결과를 계정에 귀속해 저장 — 저장 시점(자동 vs 명시적 버튼)은 정책 확정 필요 | Y |
| 즐겨찾기 | GET | `/api/v1/favorites` | 즐겨찾기 목록 조회 | Y |
| 즐겨찾기 | POST | `/api/v1/favorites` | 즐겨찾기 추가 (대상: 진단 결과 또는 주소 — 정책 확정 필요) | Y |
| 즐겨찾기 | DELETE | `/api/v1/favorites/{id}` | 즐겨찾기 삭제 | Y |
| 지도 | GET | `/api/v1/map/geocode?address=` | 카카오맵으로 좌표 조회 후 서울 지원 지역 여부 판별, `region_id`/`hdd_lookup_key` 반환. 서울 밖이면 `UNSUPPORTED_REGION` | Y |

**정책 확정 필요 (BE-A):**
- 로그인 세션 전달 방식 — Authorization 헤더 vs httpOnly 쿠키
- 세션 만료 정책 (TTL, 재로그인 유도 방식)
- `POST /diagnoses/calculate` 결과를 계정에 저장하는 시점 — 계산 즉시 자동 저장인지, 사용자가 "저장" 버튼을 눌러야 하는지
- 즐겨찾기 대상 데이터 모델 (진단 결과 1건 vs 주소/지역 단위)

---

## 2. 엔드포인트 상세

### 2.1 GET `/api/v1/regions`

지원 지역 목록. 자유 시군구 입력은 없고 이 목록에서만 선택한다.

**Response 200**
```json
{
  "data_version": "region-seed-v1",
  "regions": [
    {
      "region_id": "seoul",
      "display_name": "서울특별시",
      "hdd_lookup_key": "seoul",
      "climate_zone": "central-1",
      "climate_zone_description": "중부1지역",
      "supported": true
    },
    {
      "region_id": "gimpo",
      "display_name": "경기도 김포시",
      "hdd_lookup_key": "gimpo",
      "climate_zone": "central-1",
      "climate_zone_description": "중부1지역",
      "supported": true
    }
  ]
}
```

- `region_id`가 아닌 값은 이후 모든 API에서 `UNSUPPORTED_REGION` 처리.

### 2.2 GET `/api/v1/reference/options`

입력 폼 선택지. **U값·HDD 실수치는 절대 포함하지 않는다** — enum/라벨/버전만 내려준다.

**Response 200**
```json
{
  "options_version": "options-seed-v1",
  "building_types": [
    { "value": "detached_multi_household", "label": "단독·다가구주택", "u_value_reference_group": "non_apartment" },
    { "value": "apartment", "label": "아파트", "u_value_reference_group": "apartment" }
  ],
  "representative_space_types": [
    { "value": "living_room", "label": "거실" },
    { "value": "main_bedroom", "label": "주침실" },
    { "value": "other", "label": "기타 대표 공간" }
  ],
  "window_type_options": [
    { "value": "single", "label": "단창" },
    { "value": "double", "label": "복층창" },
    { "value": "triple", "label": "삼중창" }
  ],
  "low_e_options": [
    { "value": "yes", "label": "Low-E 적용" },
    { "value": "no", "label": "Low-E 미적용" },
    { "value": "unknown", "label": "모름" }
  ],
  "construction_year_ranges": [
    { "value": "TBD", "label": "TBD — BE-C 정책 확정 필요", "min_year": null, "max_year": null }
  ],
  "wall_insulation_status_options": [
    { "value": "none", "label": "단열 없음/모름" },
    { "value": "partial", "label": "부분 단열" },
    { "value": "good", "label": "양호" }
  ],
  "wall_visible_anomaly_confirm_options": [
    { "value": "suspected", "label": "이상 흔적 있음 (현장 점검 권장)" },
    { "value": "none_observed", "label": "이상 흔적 없음" }
  ]
}
```

> ⚠️ `construction_year_ranges`는 실제 구간 경계를 이 문서에서 확정하지 않는다. PRD 원칙 3("기준이 모호할 때 임의 수치나 정책을 확정하지 않는다")에 따라 BE-C가 별표1 옛 버전 근사 정책을 검증 후 DB에 시드하고, 이 API는 그 값을 그대로 조회해 내려준다. FE는 이 리스트를 하드코딩하지 않고 API 응답으로 렌더링한다.
> `wall_insulation_status_options`는 계산에 쓰이지 않는 저장용 필드라 여기서는 제안값으로 표기했고, 최종 라벨은 팀 확인 후 확정한다.

### 2.3 POST `/api/v1/photos/analyze`

사진 1장을 Vision API에 일회성으로 전달하고 구조화된 후보값만 반환한다. 서버는 원본을 저장하지 않는다.

> **전제**: 이 API는 **FE에서 클라이언트 사전 블러 체크를 통과한 사진에 대해서만 호출된다.** 라플라시안 분산(Laplacian variance) 기반으로 흐림 정도를 로컬에서 먼저 판정하고, 임계값 미달이면 이 API를 호출하지 않고 즉시 "사진이 흐려요, 다시 찍어주세요"를 표시한다(네트워크 왕복 없음). 상세는 5.0절 참고.

**Request** `multipart/form-data`

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `category` | string | Y | `"window"` \| `"wall"` |
| `image` | file | Y | jpeg/png/webp, 최대 10MB |

**Response 200** (성공/우아한 실패 모두 200 — AI 실패가 전체 진단 실패가 되지 않게 함)
```json
{
  "assessment_status": "completed",
  "photo_quality": "usable",
  "component_type": "window",
  "window_type_candidate": "double",
  "visible_anomaly_candidate": "not_applicable",
  "needs_user_confirmation": true,
  "reason_summary": "창틀 이중 프레임과 유리 간격이 복층창 형태로 보입니다.",
  "model_version": "gpt-4o-vision-2024xx (VISION_MODEL 값)"
}
```

`assessment_status`별 의미:
- `completed`: 후보 산출됨 → 그래도 `needs_user_confirmation: true` 유지, 사용자 확인 UI로 이동
- `unassessable`: 사진은 유효하나 AI가 판단 불가 → 수동 선택 유도
- `failed`: Vision API 타임아웃/5xx/응답 스키마 위반 등 → 수동 선택 폴백 (계산 진행은 사용자가 수동 확정하면 가능)

**Error responses** (요청 자체가 잘못된 경우만 4xx, AI 쪽 실패는 200+`failed`로 처리)

| status | error_code | 상황 |
|---|---|---|
| 400 | `PHOTO_INVALID_FORMAT` | 지원하지 않는 파일 형식 |
| 400 | `PHOTO_TOO_LARGE` | 용량 초과 |
| 400 | `PHOTO_CORRUPTED` | 이미지 무결성 검증 실패 |
| 400 | `PHOTO_CATEGORY_INVALID` | category 값이 window/wall 아님 |

### 2.4 POST `/api/v1/diagnoses/calculate`

사용자 확정값 일괄 전달 → 서버 계산 → 기준선/시나리오 반환.

**Request**
```json
{
  "building": {
    "building_type": "apartment",
    "representative_space_type": "living_room",
    "construction_year_range": "<reference/options 조회값>"
  },
  "space": {
    "width_m": 4.2,
    "depth_m": 3.5,
    "height_m": 2.4,
    "floor_area_m2": 14.7,
    "input_source": "manual"
  },
  "window": {
    "total_area_m2": 3.6,
    "window_type": "double",
    "low_e": "unknown",
    "input_source": "user_corrected"
  },
  "wall": {
    "exterior_total_area_m2": 12.0,
    "insulation_status": "none",
    "visible_anomaly_confirmed": "none_observed",
    "input_source": "manual"
  },
  "location": {
    "region_id": "seoul"
  },
  "bill": null
}
```

- `window.window_type`은 `single/double/triple` 중 하나만 허용 (candidate의 `unknown`은 계산 입력으로 못 옴 — 사용자가 반드시 3개 중 하나로 확정).
- `wall.visible_anomaly_confirmed`는 `suspected/none_observed` 중 하나만 허용 (계산값에는 영향 없음, 현장점검 안내 문구에만 영향).
- `input_source`는 `manual` \| `user_corrected`만 허용, `lidar`는 이번 MVP에서 API가 받지 않음(스키마 예약만).
- 서버는 `wall_net_area_m2 = exterior_total_area_m2 - window.total_area_m2` 를 계산해 0 이하면 차단.

**Response 200**
```json
{
  "calculation_version": "calc-v1",
  "reference_data_version": {
    "current_u_value_window": "u-window-v1",
    "current_u_value_wall": "u-wall-v1",
    "target_u_value": "target-u-v1",
    "hdd": "hdd-seed-v1"
  },
  "baseline": {
    "window_heat_loss_kwh": 812.4,
    "wall_heat_loss_kwh": 540.1,
    "total_heat_loss_kwh": 1352.5
  },
  "scenarios": [
    {
      "scenario_id": "window_upgrade",
      "name": "창호 개선",
      "changed_components": ["window"],
      "annual_reduction_kwh": 410.2,
      "reduction_rate": 0.303,
      "priority": 1
    },
    {
      "scenario_id": "wall_upgrade",
      "name": "벽체 개선",
      "changed_components": ["wall"],
      "annual_reduction_kwh": 210.5,
      "reduction_rate": 0.156,
      "priority": 2
    },
    {
      "scenario_id": "combined_upgrade",
      "name": "복합 개선",
      "changed_components": ["window", "wall"],
      "annual_reduction_kwh": 590.8,
      "reduction_rate": 0.437,
      "priority": 3
    }
  ],
  "wall_anomaly_notice": {
    "status": "none_observed",
    "message": "사진상 뚜렷한 이상 흔적은 확인되지 않았습니다. 이 값은 열손실 수치에 영향을 주지 않습니다."
  },
  "unit_scope_disclaimer": "이 결과는 대표 공간 1개 기준 비공식 추정치입니다. 천장, 바닥, 환기, 침기, 일사, 난방기기 효율, 사용 습관은 포함하지 않습니다.",
  "bill_comparison": null
}
```

절감률(`reduction_rate`)의 분모는 항상 `baseline.total_heat_loss_kwh`. `priority`는 `annual_reduction_kwh` 내림차순.

**Error responses**

| status | error_code | 상황 | 계산 진행 |
|---|---|---|---|
| 400 | `UNSUPPORTED_REGION` | region_id가 지원 목록 밖 | 불가 |
| 400 | `INVALID_ENUM_VALUE` | building_type/window_type/low_e/visible_anomaly_confirmed 등 허용값 밖 | 불가 |
| 400 | `INVALID_INPUT_SOURCE` | input_source가 manual/user_corrected 밖 (예: lidar) | 불가 |
| 422 | `WALL_NET_AREA_INVALID` | 외기접촉벽체순면적 ≤ 0 | 불가, 입력 화면 복귀 |
| 422 | `UNCONFIRMED_INPUT` | window_type이 확정 안 됨 등 필수 확정값 누락 | 불가 |
| 422 | `REFERENCE_DATA_MISSING` | 조합에 대한 U값/HDD/목표U값 기준 데이터 없음 | 불가, `detail.missing`에 어떤 조회가 실패했는지 명시 |
| 500 | `INTERNAL_ERROR` | 그 외 서버 오류 | 불가 |

### 2.5 POST `/api/v1/bills/compare` (Should, MVP 후순위)

참고용. 핵심 계산에 영향 없음. Must 흐름 완성 후 착수 (PRD 10.1 구현순서 6번).

**Request**
```json
{
  "energy_source": "gas",
  "usage_period": "2026-08",
  "usage_amount": 220,
  "unit": "m3",
  "baseline_total_heat_loss_kwh": 1352.5
}
```

**Response 200**
```json
{
  "comparison_note": "참고용 비교이며 핵심 계산 보정에는 사용되지 않았습니다.",
  "comparison_result": null
}
```

> 비교 로직(단위 환산, 원단위 등)은 정책 확정 필요 — 이번 설계에서는 엔드포인트 계약만 정의.

---

## 3. 상태 전이 ↔ API 매핑

PRD 8.1 상태를 API 호출 시점에 매핑한다. 모든 상태는 **클라이언트 임시 상태**이며 서버에 저장되지 않는다.

| 상태 | 트리거 | 관련 API |
|---|---|---|
| `input_pending` | 화면 진입 | `GET /regions`, `GET /reference/options` |
| `photo_pending` | 공간 입력 완료 | 없음 (클라이언트 전환) |
| `ai_analyzing` | 사진 제출 | `POST /photos/analyze` |
| `confirmation_required` | 분석 응답 수신 (성공/실패 모두) | 없음 (클라이언트 전환) |
| `calculation_ready` | 모든 필수값 사용자 확정 | 없음 (클라이언트 검증) |
| `completed` | 계산 성공 | `POST /diagnoses/calculate` 200 |
| `recoverable_error` | 4xx/422 응답 | 해당 API 응답의 `error_code` |
| `failed` | 500 또는 복구 불가 오류 | 해당 API 응답의 `error_code` |

## 4. 오류 코드 총괄표 (PRD 8.2 매핑)

| PRD 8.2 오류 | error_code | HTTP | 계산 진행 가능 여부 |
|---|---|---|---|
| 사진 형식/용량/손상 | `PHOTO_INVALID_FORMAT` / `PHOTO_TOO_LARGE` / `PHOTO_CORRUPTED` | 400 | 불가, 재업로드 |
| 사진 품질 부족 | (응답 필드 `photo_quality: retake_required`, 별도 4xx 아님) | 200 | 수동 확정 시 가능 |
| Vision API 일시 실패 | (응답 필드 `assessment_status: failed`) | 200 | 수동 확정 시 가능 |
| Vision 응답 스키마 오류 | (응답 필드 `assessment_status: failed`) | 200 | 수동 확정 시 가능 |
| 입력값 누락/면적 모순 | `UNCONFIRMED_INPUT` / `WALL_NET_AREA_INVALID` / `INVALID_ENUM_VALUE` | 400/422 | 불가 |
| 기준 데이터 누락 | `REFERENCE_DATA_MISSING` | 422 | 불가 |
| 지원 지역 밖 | `UNSUPPORTED_REGION` | 400 | 불가 |
| 서버 내부 오류 | `INTERNAL_ERROR` | 500 | 불가 |

> Vision 관련 실패를 의도적으로 HTTP 에러가 아닌 `200 + assessment_status`로 설계했다 — PRD "AI 실패가 전체 진단 실패가 되지 않는다"(통합테스트 5번)를 API 레벨에서 강제하기 위함. FE는 이 응답을 정상 흐름의 한 분기로 처리하면 된다.

---

## 5. Vision API 연동 설계

### 5.0 클라이언트 사전 블러 체크 (FE)

Vision API 호출 전, FE가 로컬에서 먼저 사진 흐림 여부를 판정해 불필요한 API 왕복을 줄인다.

- 방식: 이미지를 그레이스케일로 변환 후 라플라시안(Laplacian) 커널을 적용, 그 결과값의 **분산(variance)** 을 구한다. 분산이 낮을수록 경계(edge)가 적다는 뜻이라 흐린 사진일 가능성이 높다.
- 임계값 미달 시: `POST /photos/analyze`를 호출하지 않고 클라이언트에서 즉시 "사진이 흐려요, 다시 찍어주세요" 안내(재촬영 유도) → PRD 6.1 "재촬영 안내"의 클라이언트 측 1차 방어선.
- 구현 참고: OpenCV의 `cv2.Laplacian(gray, cv2.CV_64F).var()`와 동일한 원리를 웹 캴버스(Canvas API)로 구현 — 이미지를 `<canvas>`에 그린 뒤 픽셀 데이터에 3x3 라플라시안 커널 컨볼루션을 적용해 분산을 계산.
- 임계값 자체는 이번 문서에서 확정하지 않는다(정책 확정 필요, 아래 6장 표에 추가). 실측 샘플로 튜닝 필요.
- 이 체크를 통과했다고 서버가 재검증을 생략하는 것은 아니다 — 서버는 여전히 `PHOTO_CORRUPTED` 등 자체 무결성 검증을 수행한다(2.3절 오류표). 블러 체크는 어디까지나 "명백히 흐린 사진"을 조기에 걸러 API 호출 낭비를 줄이는 보조 수단이다.

### 5.1 역할 경계 (프롬프트 설계 원칙)

- Vision 모델은 **실측기가 아니라 후보 분류기**다. 실제 길이/면적/U값/구조안전성/누수원인을 확정하지 않는다.
- 응답은 반드시 6.2 스키마의 구조화 JSON만 반환하게 강제한다. 자유 텍스트 설명은 `reason_summary` 한 필드로만 제한.
- `needs_user_confirmation`은 항상 `true`로 응답하게 하고, 서버도 이를 신뢰하지 않고 항상 `true`로 덮어쓴다(모델이 다르게 응답해도 무시).
- confidence류 수치를 모델이 반환하더라도 서버는 계산 자동 확정에 쓰지 않고 로그/응답에도 노출하지 않는다.

### 5.2 시스템 프롬프트 (확정, 2026-09-11 BE-B)

초안 대비 변경: 카테고리(window/wall)별로 판단 기준을 분리해 PRD 6.1 촬영
가이드를 각각 반영했다. 공통 규칙은 그대로 유지하고, 카테고리별 지시문을
이어붙이는 구조다. 실제 구현은 `backend/app/services/vision_service.py`의
`_BASE_SYSTEM_PROMPT` + `_CATEGORY_GUIDANCE`를 따른다 — 이 문서는 그 요약이며,
코드가 바뀌면 이 절도 함께 갱신한다.

**공통 규칙**
```
너는 주택 진단 보조 도구의 사진 분류기다. 창호 또는 벽체 사진 한 장을 보고 후보값만 제시한다.

공통 역할 경계:
- 너는 실제 측정 도구가 아니다. 길이, 면적, 정확한 U값을 추정하지 않는다.
- 창호 유형(단창/복층창/삼중창)은 후보일 뿐이며 최종 확정이 아니다.
- 벽체 사진에서는 균열, 누수 흔적 등 이상 흔적의 "가능성"만 후보로 제시한다.
  실제 구조 안전성, 누수 원인, 단열재 유무를 진단하지 않는다.
- 사진이 어둡거나, 강한 반사가 있거나, 대상이 화면에서 너무 작게(과도한 원거리)
  찍혔으면 photo_quality를 retake_required로 표시한다.
- 판단이 애매하면 unknown/unassessable을 적극적으로 사용한다. 추측으로 값을
  채우지 않는다.
- 입력 사진 카테고리는 아래 안내된 값이다. component_type은 이 카테고리와
  일치해야 하며, 사진이 해당 카테고리로 보이지 않으면 component_type을
  "unknown"으로 답하고 reason_summary에 그 이유를 적는다.

반드시 주어진 JSON 스키마 형식으로만 응답한다.
```

응답 JSON 스키마는 6.2절과 동일:
```
{
  "assessment_status": "completed" | "unassessable" | "failed",
  "photo_quality": "usable" | "retake_required" | "unknown",
  "component_type": "window" | "wall" | "unknown",
  "window_type_candidate": "single" | "double" | "triple" | "unknown" | "not_applicable",
  "visible_anomaly_candidate": "suspected" | "none_observed" | "unassessable" | "not_applicable",
  "needs_user_confirmation": true,
  "reason_summary": "한국어 2문장 이내 짧은 근거"
}
```

**카테고리별 지시문 (요약)**
- `window`: usable 조건은 창틀 프레임+유리 면이 함께 보이는 것. 프레임 겹 구조로만
  window_type_candidate 판단. visible_anomaly_candidate는 항상 not_applicable.
- `wall`: usable 조건은 의심 부위(균열/누수/곰팡이 등)가 선명하게 보이는 것.
  visible_anomaly_candidate는 원인 추정 없이 "흔적 존재 가능성"만 판단.
  window_type_candidate는 항상 not_applicable.

카테고리상 의미 없는 필드(window의 anomaly, wall의 window_type)는 모델이
프롬프트를 어겨도 서버(`analyze_photo`)가 응답 후처리에서 다시 한 번
`not_applicable`로 강제한다 — AI 원본 응답만으로 확정하지 않는다는
PRD 6.2 원칙을 이 경계에도 동일하게 적용한 것이다.

### 5.3 호출/재시도 정책

- 호출 방식: **OpenAI 파이썬 SDK 사용으로 확정**(2026-09-11, PM 합의 — 0.1절 참고). `backend/app/services/vision_service.py`의 `OpenAI` 클라이언트 구현이 정책과 일치한다.
- 재시도: 일시적 오류(타임아웃, 연결 오류, 5xx)에 한해 `tenacity`로 재시도한다. **정책 확정(2026-09-11, BE-B): 최대 3회, 1초→8초 지수 백오프.** 4xx(잘못된 요청, 인증 실패 등)는 재시도 대상에서 제외한다.
- 재시도 후에도 실패하면 `assessment_status: "failed"`로 정규화해 응답 (HTTP 200 유지).
- 응답이 스키마를 지키지 않으면(JSON 파싱 실패, 허용값 밖 enum 등) 서버가 `failed`로 강제 변환 — 모델의 원본 응답을 그대로 신뢰해 계산에 넘기지 않는다.

### 5.4 사진 일회성 처리 & 고지

- FastAPI는 업로드된 파일을 메모리 버퍼 또는 임시파일로만 받아 Vision API 요청에 사용하고, 응답 수신 즉시 버퍼/임시파일을 닫고 삭제한다. 어떤 단계에서도 S3/디스크/DB에 원본을 쓰지 않는다.
- 요청 처리 중 예외가 나도 `finally` 블록에서 임시파일 삭제를 보장한다(구현 시 반드시 지킬 것 — 통합테스트 9번 "원본 폐기" 기준).
- 화면 고지 문구(FE 표시용, API 응답에도 동일 문구 포함 권장): "업로드한 사진은 AI 분석을 위해 외부 API로 전송되며, GreenScan 서버에는 원본이 저장되지 않습니다."

---

## 6. 미확정 정책값 (Open Policy Points)

아래는 이번 API 설계에서 임의로 확정하지 않고 열어둔 값들. 각 담당이 검증 후 채워야 함.

| 항목 | 담당 | 비고 |
|---|---|---|
| `construction_year_range` 구간 경계 | BE-C | 별표1 옛 버전 근사 정책, 시행일 기준 확인 필요 |
| `wall.insulation_status`의 최종 enum/라벨 | PM/BE-C | 계산 미사용이지만 향후 확장 대비 값 확정 필요 |
| ~~사진 업로드 최대 용량/허용 포맷~~ | BE-B | **확정(2026-09-11): 10MB, jpeg/png/webp.** 0.1절 참고 |
| ~~Vision 재시도 횟수/timeout~~ | BE-B | **확정(2026-09-11): 최대 3회, 1초→8초 지수 백오프.** 5.3절 참고 |
| ~~Vision 호출 방식 (SDK vs 범용 HTTP)~~ | PM/BE-B | **확정(2026-09-11): OpenAI SDK 사용.** 0.1, 5.3절 참고 |
| `floor_area_m2` vs `width×depth` 크로스체크 허용 오차 | BE-A/PM | 초과 시 경고만 할지, 차단할지 결정 필요 |
| `low_e: unknown`에 대한 현재 추정 U값 정책 행 | BE-C | "모름"도 선택 가능한 값이라 반드시 정책 테이블에 행 필요 |
| `bills/compare`의 실제 비교 로직/단위환산 | BE-C | Should 우선순위, Must 완료 후 착수 |
| 클라이언트 블러체크(라플라시안 분산) 임계값 | FE/BE-B | 실측 샘플로 튜닝 필요, 기기별 카메라 화질 편차 고려 |

---

## 7. Mock JSON (FE-BE 공유용)

### `GET /regions` mock
`docs/mocks/regions.json` 참고 내용과 동일 (본문 2.1 예시 그대로 사용 가능)

### `POST /photos/analyze` mock — 성공
```json
{
  "assessment_status": "completed",
  "photo_quality": "usable",
  "component_type": "wall",
  "window_type_candidate": "not_applicable",
  "visible_anomaly_candidate": "suspected",
  "needs_user_confirmation": true,
  "reason_summary": "벽면 하단에 얼룩으로 보이는 흔적이 있습니다. 현장 확인을 권장합니다.",
  "model_version": "mock-vision-v1"
}
```

### `POST /photos/analyze` mock — AI 실패
```json
{
  "assessment_status": "failed",
  "photo_quality": "unknown",
  "component_type": "unknown",
  "window_type_candidate": "unknown",
  "visible_anomaly_candidate": "unassessable",
  "needs_user_confirmation": true,
  "reason_summary": "AI 분석에 실패했습니다. 수동으로 선택해 주세요.",
  "model_version": "mock-vision-v1"
}
```

### `POST /diagnoses/calculate` mock — 오류(면적 모순)
```json
{
  "error_code": "WALL_NET_AREA_INVALID",
  "message": "외기 접촉 벽체 순면적이 0 이하입니다. 벽체 면적과 창호 면적을 다시 확인해 주세요.",
  "detail": {
    "exterior_total_area_m2": 3.0,
    "window_total_area_m2": 3.6,
    "wall_net_area_m2": -0.6
  }
}
```

성공 응답 mock은 2.4절 예시를 그대로 사용.

---

## 8. 다음 단계 제안

- 이 문서 리뷰 후 확정되면 DB ERD/DBML(9.2, 13장 3번 항목)을 별도 문서로 설계.
- 6장 "미확정 정책값"은 BE-C/PM 확인 결과로 이 문서를 업데이트.
- FE는 이 문서의 mock을 그대로 사용해 계산 API 연동 전 화면을 먼저 완성 가능(PRD 10.1 구현순서 1번과 일치).
