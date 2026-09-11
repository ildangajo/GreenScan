"""준공연도 구간, 단열 상태, 현재 벽체 U값 시드.

출처: 마루건축사사무소 "단열재의 두께 기준 변천사(1980~2016년)" 정리글에서
확인한 실제 고시 원문 발췌:
- 「건축물의 에너지절약 설계기준」[시행 2016.1.1., 별표1/별표3은 2016.7.1
  시행] (국토교통부고시 제2015-1108호, 2015.12.31. 일부개정) 별표1
- 「건축물의 에너지절약설계기준」(국토교통부고시 제2023-104호) 별표1
  (seed_target_u_values.py에서 이미 시드한 reference_document 재사용)

⚠️ 범위 제한 (임의로 채우지 않음, 2026-09-11 팀 확인):
- 2016년 7월 이전 준공 건물은 여기서 다루지 않는다. 그 이전 고시는 U값을
  직접 명시하지 않고 "단열재 두께 몇 mm 이상"으로만 규정해서, U값으로
  환산하려면 단열재 종류별 열전도율 가정이 필요해 정확도가 떨어진다.
  이 구간은 construction_year_ranges에 행을 만들지 않는다 — 사용자가
  선택할 수 없으므로 계산에서 자동으로 배제된다(REFERENCE_DATA_MISSING
  발생 없이 애초에 선택지에 없음).
- current_wall_u_value_policies의 building_group(공동주택/공동주택외)
  구분이 스키마에 없어(construction_year_range × insulation_status만
  조회 키), "공동주택 외"(단독·다가구주택에 가까운, 더 완화된) 값을
  대표값으로 채택했다 — 창호 때와 동일한 이유로 노후주택 근사치.
- insulation_status는 "양호"(그 시기 법정 기준을 지킨 경우)만 채운다.
  "부분"/"없음"에 대응하는 실제 수치 근거를 찾지 못했으므로 임의로 만들지
  않고 비워둔다 — 계산 시 REFERENCE_DATA_MISSING으로 정직하게 막힌다.

실행: python -m app.db.seed.seed_construction_year_wall_u (재실행해도 안전)
"""

import uuid
from datetime import date

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.building import ConstructionYearRange, InsulationStatus
from app.models.reference_document import ReferenceDocument
from app.models.u_value_policy import CurrentWallUValuePolicy

_POLICY_VERSION = "construction-year-v1"

_YEAR_RANGES = [
    # key, label, start_year, end_year
    ("2016_2023", "2016년 7월 ~ 2023년 2월", 2016, 2023),
    ("2023_present", "2023년 2월 이후", 2023, None),
]

_INSULATION_STATUSES = [
    ("none", "단열 없음/모름"),
    ("partial", "부분 단열"),
    ("good", "양호"),
]

# 중부지역/중부2지역, 외기 직접 면하는 경우, 공동주택 외(단독·다가구 근사치) — W/m2K
_WALL_U_BY_YEAR_RANGE = {
    "2016_2023": 0.260,
    "2023_present": 0.240,
}


def seed_construction_year_wall_u() -> None:
    db = SessionLocal()
    try:
        doc = db.scalar(
            select(ReferenceDocument).where(
                ReferenceDocument.reference_name == "건축물의 에너지절약 설계기준",
                ReferenceDocument.reference_version == "제2015-1108호",
            )
        )
        if doc is None:
            doc = ReferenceDocument(
                reference_document_id=uuid.uuid4(),
                reference_name="건축물의 에너지절약 설계기준",
                notice_number="국토교통부고시 제2015-1108호",
                reference_version="제2015-1108호",
                effective_date=date(2016, 7, 1),
                source_document=(
                    "마루건축사사무소 '단열재의 두께 기준 변천사(1980~2016년)' 정리글에서 원문 발췌 확인, "
                    "별표1(지역별 건축물 부위의 열관류율표) 부칙: 별표1·별표3은 2016.7.1 시행"
                ),
            )
            db.add(doc)
            db.flush()
            print(f"reference_documents 추가: {doc.reference_name} {doc.reference_version}")

        doc_2023 = db.scalar(
            select(ReferenceDocument).where(
                ReferenceDocument.reference_name == "건축물의 에너지절약설계기준",
                ReferenceDocument.reference_version == "제2023-104호",
            )
        )
        if doc_2023 is None:
            raise RuntimeError(
                "reference_documents에 제2023-104호가 없습니다. "
                "먼저 python -m app.db.seed.seed_target_u_values 를 실행하세요."
            )

        for key, label, start_year, end_year in _YEAR_RANGES:
            if db.get(ConstructionYearRange, key) is None:
                db.add(
                    ConstructionYearRange(
                        construction_year_range_key=key,
                        display_name=label,
                        start_year=start_year,
                        end_year=end_year,
                    )
                )
                print(f"construction_year_ranges 추가: {key}")

        for key, label in _INSULATION_STATUSES:
            if db.get(InsulationStatus, key) is None:
                db.add(InsulationStatus(insulation_status_key=key, display_name=label))
                print(f"insulation_statuses 추가: {key}")
        db.flush()

        doc_by_range = {"2016_2023": doc, "2023_present": doc_2023}
        for range_key, u_value in _WALL_U_BY_YEAR_RANGE.items():
            existing = db.scalar(
                select(CurrentWallUValuePolicy).where(
                    CurrentWallUValuePolicy.construction_year_range_key == range_key,
                    CurrentWallUValuePolicy.insulation_status_key == "good",
                    CurrentWallUValuePolicy.policy_version == _POLICY_VERSION,
                )
            )
            if existing is None:
                db.add(
                    CurrentWallUValuePolicy(
                        construction_year_range_key=range_key,
                        insulation_status_key="good",
                        u_value_w_m2k=u_value,
                        policy_version=_POLICY_VERSION,
                        reference_document_id=doc_by_range[range_key].reference_document_id,
                    )
                )
                print(f"current_wall_u_value_policies 추가: {range_key}/good = {u_value}")

        db.commit()
        print("완료.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_construction_year_wall_u()
