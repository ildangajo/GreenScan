"""에너지 효율 레벨(LV.1~5) 밴드 시드 (calc-v2, docs/result-screen-v9-design.md 1절).

⚠️ 임계값은 서울 HDD 중간값 × 표준 단열 수준으로 역산한 잠정 추정치다 —
실제 진단 데이터 분포를 본 뒤 조정이 필요한 정책 확정 필요 항목이다.
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
