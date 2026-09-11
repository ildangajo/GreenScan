"""에너지 효율 레벨(LV.1~5) 밴드 시드 (calc-v2, docs/result-screen-v9-design.md 1절).

⚠️ 임계값은 여전히 잠정 추정치다(외부 공식 등급 체계에서 그대로 가져온 게
아님 — 이 앱의 계산 범위가 난방 관련 외피 열손실만 다뤄서(냉방/급탕/조명
제외), 국토교통부의 건축물 에너지효율등급 인증 같은 공식 체계와 범위가
안 맞아 그대로 갖다 쓰면 오히려 오도할 수 있다고 판단했다).

2026-09-12 검증: 운영 서버에 실제 계산 요청을 여러 시나리오로 보내
관측값 범위와 5구간 임계값이 서로 맞물려 돌아가는지 확인했다(대표
공간 하나 기준, "양호" 단열 고정):
  - 신축+큰 방+복층창: 57 kWh/㎡ → LV.5(매우 좋음)
  - 오래된 연식+복층창: 101 → LV.4(좋음)
  - 오래된 연식+단창: 163 → LV.3(보통)
  - 좁은 방+큰 창+단창: 232 → LV.2(주의)
  - 극단적으로 좁은 방+거의 전면창+단창: 370 → LV.1(긴급)
단조 증가로 잘 맞물려서 임계값 자체는 바꾸지 않았다 — 다만 "양호"
단열만 시험 가능했다(단열 "부분"/"없음"은 U값 근거 데이터가 없어
REFERENCE_DATA_MISSING으로 막혀 있음, seed_construction_year_wall_u.py
참고). 진짜 진단 데이터가 쌓이면 그때 실측 분포로 재조정 필요.
PRD v8.3 원칙: "참고용 추정치이며 실제와 다를 수 있다" 고지를 반드시
동반해서 노출해야 한다(고지 자체는 API가 아니라 화면 책임).

실행: python -m app.db.seed.seed_energy_efficiency_bands (재실행해도 안전)
"""

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.envelope_u_value_policy import EnergyEfficiencyBand

_POLICY_VERSION = "efficiency-band-estimate-v1"

# band_level, label, min_kwh_per_m2(제외), max_kwh_per_m2(포함) — 낮을수록 좋음.
_BANDS = [
    (5, "매우 좋음", None, 80),
    (4, "좋음", 80, 130),
    (3, "보통", 130, 190),
    (2, "주의", 190, 260),
    (1, "긴급", 260, None),
]


def seed_energy_efficiency_bands() -> None:
    with SessionLocal() as db:
        for level, label, min_v, max_v in _BANDS:
            existing = db.scalar(
                select(EnergyEfficiencyBand).where(
                    EnergyEfficiencyBand.band_level == level,
                    EnergyEfficiencyBand.policy_version == _POLICY_VERSION,
                )
            )
            if existing:
                existing.label = label
                existing.min_kwh_per_m2 = min_v
                existing.max_kwh_per_m2 = max_v
            else:
                db.add(
                    EnergyEfficiencyBand(
                        band_level=level,
                        label=label,
                        min_kwh_per_m2=min_v,
                        max_kwh_per_m2=max_v,
                        policy_version=_POLICY_VERSION,
                    )
                )
        db.commit()
        print(f"에너지 효율 레벨 밴드 시드 완료 (policy_version={_POLICY_VERSION})")


if __name__ == "__main__":
    seed_energy_efficiency_bands()
