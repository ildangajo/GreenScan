# 라이다(RoomPlan) 공간 실측 — BE 연동 제안

작성: iOS(FE) · 2026-09-12
관련: `docs/api-spec.md` 2.4절(`POST /diagnoses/calculate`), `backend/app/schemas/diagnosis.py`

## 배경

지금 `SpaceInput`/`WindowInput`/`WallInput`은 사용자가 자로 재서 직접 입력하는
값이다. `input_source: InputSource`에 `lidar`가 이미 **예약값으로 정의**돼 있지만
(`backend/app/schemas/diagnosis.py` `InputSource` enum 주석: "lidar는 PRD상
예약값일 뿐 이번 MVP API가 받지 않는다"), 실제로 보내면 `400
INVALID_INPUT_SOURCE`로 막힌다(`api-spec.md` 2.4절 오류표).

iOS 클라이언트가 실기기(라이다 탑재 iPhone Pro/iPad Pro)에서 Apple
`RoomPlan` 프레임워크로 방을 스캔해 치수를 자동 추출하는 기능을 붙이려고
한다 — 그러려면 이 예약값을 실제로 받아주는 작업이 BE에 필요하다.

## RoomPlan이 주는 원본 데이터

`RoomCaptureView`로 스캔하면 `CapturedRoom` 객체가 나온다. 우리가 쓸 필드:

| RoomPlan 필드 | 내용 |
|---|---|
| `walls: [Surface]` | 벽 각각의 `dimensions`(width, height, thickness), `transform`, `confidence`(.low/.medium/.high) |
| `windows: [Surface]` | 창 각각의 `dimensions`(width, height), 어느 벽에 속하는지 |
| `doors: [Surface]` | 문(면적 계산에서 제외 대상) |
| `openings: [Surface]` | 벽 없는 개구부 |
| `floors: [Surface]` | 바닥 폴리곤 → 면적 |

**중요한 제약**: RoomPlan은 벽을 "내벽/외벽(외기 접촉 여부)"으로 자동 분류하지
않는다 — 이건 실내 스캔만으로는 원리적으로 판별 불가(옆집·복도와 접한 벽도
똑같이 잡힘). 그래서 스캔 직후 **사용자가 화면에서 벽을 골라 "외기 접촉"
표시를 해야** `wall.exterior_total_area_m2`를 만들 수 있다. UI 아이디어:
스캔 결과를 평면도로 보여주고 벽을 탭해서 켜고 끄는 방식.

## 계산 API 필드 매핑

| CalculateRequest 필드 | 산출 방법 |
|---|---|
| `space.width_m` / `depth_m` | 바닥 폴리곤의 바운딩박스 두 변 |
| `space.height_m` | 벽 `dimensions`의 높이 평균(또는 최댓값) |
| `space.floor_area_m2` | 바닥 폴리곤 면적(신발끈 공식) |
| `window.total_area_m2` | `windows[].dimensions.width * height` 합산 |
| `wall.exterior_total_area_m2` | 사용자가 "외기 접촉"으로 표시한 벽들의 면적 합 |
| `space/window/wall .input_source` | **`"lidar"`** (사용자가 스캔 후 값을 수동으로 고치면 그 필드만 `"user_corrected"`로 전환 — 기존 `window_type_candidate` 확정 패턴과 동일) |

스캔으로 못 얻는 값(`window_type`, `low_e`, `insulation_status`,
`visible_anomaly_confirmed`, `building_type`, `representative_space_type`,
`construction_year_range`, `region_id`)은 지금처럼 사용자 입력/사진분석으로
채운다 — 라이다는 **치수만** 대체한다.

## BE에 요청하는 변경

1. **`InputSource` enum에 `lidar` 추가** (`backend/app/schemas/diagnosis.py`).
   검증 로직(양수 체크 등)은 `manual`/`user_corrected`와 동일하게 취급하면
   될 것 같음 — 값의 신뢰도를 서버가 구분해서 다르게 처리할 필요가 있는지는
   BE 판단에 맡김(현재 계산 엔진이 `input_source`를 계산에 실제로 쓰는지,
   아니면 기록용 메타데이터인지부터 확인 필요).
2. **`api-spec.md` 2.4절 갱신** — 오류표의 `INVALID_INPUT_SOURCE` 조건에서
   `lidar` 제외, 요청 예시에 `lidar` 케이스 하나 추가.
3. (선택) 스캔 신뢰도를 나중에 쓸 수 있게 `CapturedRoom`의 `confidence`를
   어딘가 남겨두고 싶다면 — 예: `space.input_source`와 별개로
   `space.measurement_confidence` 같은 선택 필드. **지금 MVP 범위는 아니고,
   필요해지면 그때 논의.**

## iOS 쪽 진행 순서 (참고용)

1. `RoomCaptureView`로 스캔 → `CapturedRoom` 획득 (실기기 전용, 시뮬레이터 불가)
2. 벽 목록을 평면도로 보여주고 "외기 접촉" 벽 사용자가 선택
3. 위 매핑표대로 `SpaceInput`/`WindowInput`/`WallInput` 채우고 `input_source: "lidar"`
4. 기존 수동 입력 화면(SpaceInputPage 대응 화면)은 폴백으로 유지 — "라이다로
   측정" 버튼이 필드를 미리 채워주고, 사용자가 그 위에서 고치면
   `"user_corrected"`로 전환

**전제**: 지금 iOS 쪽 진단 플로우 자체는 보류 상태라, 이 작업은 당장 그
플로우에 붙이는 게 아니라 **BE 스키마 변경 논의를 먼저 진행하기 위한
제안서**다. 스키마가 정리되면 그때 실제 화면 작업을 시작한다.

## 전체 흐름 (FE 확정, 2026-09-12)

1. **공간 스캔 — iOS**: RoomPlan으로 벽·창문 치수 추출
2. **측정값 확인·수정 — 사용자/프론트**: 측정 오류 수정, 누락 정보 입력,
   외기에 접하는 벽 선택, 선택한 외벽과 그 벽에 속한 창문 면적 산출
3. **추가 정보 입력 — 사용자/프론트**: 지역, 건물 유형, 준공연도, 창호 유형,
   Low-E 여부, 단열 상태
4. **사진 AI 분석 — 유지 시**: 프론트 → 백엔드 → AI로 사진 전달, 분석 결과를
   프론트에 표시, 사용자가 확인·수정. 이상 흔적 여부는 점검 안내에만 쓰고
   열손실 수치에는 직접 반영하지 않음(기존 `visible_anomaly_confirmed`
   동작과 동일)
5. **최종값 전송 — 프론트 → 백엔드**: 확정된 면적 + 추가 입력값을 묶어
   `POST /api/v1/diagnoses/calculate` 호출
6. **계산 및 결과 표시 — 백엔드 → 프론트**: 입력값 검증 → DB에서 U값·HDD
   조회 → 열손실 및 개선 시나리오 계산 → 결과 반환

### 면적 전달 기준 (기존 계약과 이미 일치 — BE 추가 작업 없음)

- **외벽 면적**은 창문을 포함한 전체 면적으로 보낸다.
- **창호 면적**은 선택한 외벽에 속한 창문의 합계로 보낸다.
- **프론트에서 창호 면적을 미리 차감하지 않는다** — 순 벽체 면적
  (`wall_net_area_m2 = exterior_total_area_m2 - window.total_area_m2`)은
  백엔드가 계산한다.

이 세 규칙은 `backend/app/schemas/diagnosis.py`의 `check_wall_net_area()`가
지금 이미 정확히 이렇게 동작한다(`WallInput.exterior_total_area_m2`는 원래
"외기 접촉 벽체 **합산**면적"으로 정의돼 있고, 순면적 차감은 서버 전용
로직이다). 즉 **라이다 소스든 수동 입력이든 이 계산 흐름 자체는 바뀌지
않는다** — 위 "BE에 요청하는 변경" 절의 `InputSource` enum에 `lidar` 한
값만 추가하면 나머지는 기존 계약 그대로 태운다.
