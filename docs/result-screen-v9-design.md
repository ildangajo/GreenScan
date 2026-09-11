# 결과 화면 리디자인(v9) — 계산 로직 설계

PRD v8.3(2026-09-12, PM+디자인팀 합의)에서 도입한 결과 화면 요소의 산정 로직을
BE-C 정책으로 여기서 확정한다. 기존 calc-v1(`backend/app/services/calculation_service.py`,
창호+벽체, `u_value × area × 24 × hdd / 1000`)은 그대로 두고, 이 문서가 다루는 항목은
그 위에 얹는 **calc-v2 확장**이다.

## 1. 에너지 효율 레벨 (정성적 라벨 + LV.n)

**입력**: calc-v1의 `baseline.total_heat_loss_kwh` (확장 후엔 천장/바닥/문 포함 총합) ÷
`space.floor_area_m2` = 면적당 연간 열손실(kWh/m², 이하 "원단위 손실").

**왜 원단위인가**: 절대 kWh는 집 크기에 따라 널뛰어서 "이 집이 나쁜 편인지" 판단 기준이
안 된다. 국내외 건물 에너지효율등급(BESS, EPC 등)도 전부 면적당 지표를 쓴다 — 같은
관례를 따른다.

**밴드(정책, DB `energy_efficiency_bands` 신규 테이블로 버전 관리)**:

| 레벨 | 라벨 | 원단위 손실 (kWh/m²·년) |
|---|---|---|
| LV.5 | 매우 좋음 | ~80 |
| LV.4 | 좋음 | 80~130 |
| LV.3 | 보통 | 130~190 |
| LV.2 | 주의 | 190~260 |
| LV.1 | 긴급 | 260~ |

임계값은 HDD 중간값(서울 기준) × 표준 단열 수준으로 역산한 초벌 추정치다 — 시드 후
실제 데이터 분포 보고 조정 필요(정책 확정 필요 항목으로 db-spec.md에 등록).
**필수 고지**: "참고용 추정치이며 실제와 다를 수 있습니다" 문구를 등급 바로 옆에 항상 표시(PRD 원칙 9 유지).

## 2. 부위별 비율 파이차트 (창호/벽체/천장/바닥/문)

기존 calc-v1은 창호+벽체만 있다. 천장·바닥·문을 더하려면 각각 (면적, U값)이 필요하다.

### 면적
| 부위 | 비라이다(수동/사진) | 라이다 |
|---|---|---|
| 천장 | `space.floor_area_m2`로 근사(방은 보통 천장=바닥 면적) | RoomPlan은 천장 서피스를 따로 안 줌 — 마찬가지로 floor 서피스 면적을 그대로 재사용 |
| 바닥 | `space.floor_area_m2` | `RoomMeasurement.floorAreaM2` (실측) |
| 문 | 고정 기본값 2.0㎡(표준 실내문 1짝) | `CapturedRoom.doors[].dimensions.x * .y` 합산(실측) — **이게 지금 라이다로만 되는 유일한 실측 항목** |

### U값
창호/벽체처럼 (연식/상태)별 정책 테이블이 아직 없다 — 신규 테이블 3개 추가:
`current_ceiling_u_value_policy`, `current_floor_u_value_policy`(둘 다 `construction_year_range_key`만으로
조회, 상태 입력 없이 연식 기준 평균치 — 단열재처럼 사용자가 상태를 판별하기 어려운 부위라
단순화함), `current_door_u_value_policy`(재질 구분 없이 연식 기준 1개 값).
목표 U값은 기존 `target_u_value_policies`에 `component_key`만 `ceiling`/`floor`/`door` 3개 늘려서 추가.

### 라이다 로직 (새로 설계가 필요했던 부분)

핵심 통찰: **라이다가 실제로 새로 벌어주는 값은 '문 면적'과 '바닥 실측' 두 개뿐이다.**
천장·벽체·창호는 라이다 유무와 무관하게 기존 로직(면적 근사 또는 실측+연식 U값)을 그대로 탄다.
그래서 라이다 로직은 계산식을 바꾸는 게 아니라 **입력 조립 단계에서 어떤 면적 출처를 쓰는지
분기하는 것**으로 충분하다 — `SpaceInput.input_source`가 이미 "manual/lidar/user_corrected"를
구분하고 있으니(이번 세션에 추가함), calc-v2 확장 시 이 값을 보고:

```
if space.input_source in ("lidar", "user_corrected") and door_area_m2 is not None:
    문 면적 = 라이다 실측값
else:
    문 면적 = 기본값 2.0㎡
```

라이다로 스캔했는데 문이 하나도 안 잡힌 경우(문이 시야에 안 들어온 스캔)는 기본값으로
폴백 — `RoomScanView`가 이미 벽 목록을 사용자에게 보여주고 확인받는 것처럼, 문도 같은
리뷰 화면에 추가해서 "감지된 문: 1개, 2.1㎡" 같은 식으로 사용자가 확인/수정하게 해야
한다(SpaceInputView에 `doorArea` 필드가 아직 없음 — 이번 확장에서 같이 추가 필요).

## 3. 예상 연간 에너지 사용량 (개선 전/후)

목업의 "38,500 kWh → 25,000 kWh"는 열손실(kWh)이 아니라 "에너지 사용량"이라
표현이 다르다 — 열손실은 난방으로 보충해야 하는 열량이지 전체 에너지 사용량(냉방·
가전·조명 포함)이 아니다. 이 값을 정직하게 보여주려면 두 가지 중 하나:

(a) 표현을 "난방 에너지 사용량"으로 좁혀서 `total_heat_loss_kwh`를 난방기기 평균
    효율(예: 가스보일러 COP ~0.85)로 나눈 값을 쓴다 — 물리적으로 방어 가능.
(b) 목업 그대로 "에너지 사용량"이라고 표현하려면 전체 가전/조명 사용량 추정이
    필요한데, 이건 calc-v1 범위 밖(PRD `unit_scope_disclaimer`가 명시적으로 제외한
    항목)이라 지어내면 안 된다.

**권장: (a)로 가고 카드 라벨을 "난방 에너지 사용량"으로 문구를 조정한다** — 계산
가능한 정직한 범위 안에서 목업의 의도(개선 전/후 절대량 비교)를 살린다. 이 부분은
디자인팀과 문구 확인 필요.

## 4. AI 한 줄 평가

자유 생성 LLM 호출 없이(PRD 원칙 8, GPU/LLM 상시 의존 지양) **서버가 계산된 등급 +
1순위 우선순위 항목을 템플릿에 꽂아 조립**한다.

```
"{등급라벨} 등급이며, {1순위 항목}을(를) 개선하면 연간 최대 {reduction_rate}% 절감이 예상돼요."
예) "주의 등급이며, 창호를 개선하면 연간 최대 65% 절감이 예상돼요."
```

## 5. 개선 우선순위 (창호/단열재/누수)

- 창호·단열재(=벽체)는 기존 scenario 절감량 내림차순 그대로 재사용.
- "누수"는 물리 계산 대상이 아니다 — `wall.visible_anomaly_confirmed`(사진 AI 후보를
  사용자가 확정한 값)가 `"suspected"`면 "높음", `"none_observed"`면 목록에서 아예 뺀다
  (원칙 5: 사진만으로 누수를 진단한다고 표현 금지 — 그래서 "누수 의심" 정도로만 표기).

## 구현 순서 제안

1. DB: `energy_efficiency_bands`, `current_ceiling/floor/door_u_value_policy`,
   `target_u_value_policies`에 component 3종 추가 + 시드
2. BE: calc-v2로 calculation_service 확장 (기존 calc-v1 응답 구조에
   `ceiling/floor/door` BaselineResult 필드 + `efficiency_level` + `ai_summary` 추가)
3. iOS: SpaceInputView에 문 면적 입력 필드 추가, RoomScanView 리뷰 화면에 감지된 문
   표시, ResultView가 새 응답 필드 렌더링

먼저 1~2(백엔드)부터 할지, 확인 부탁.
