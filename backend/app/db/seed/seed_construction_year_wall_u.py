"""준공연도 구간, 단열 상태, 현재 벽체 U값 시드.

출처: (사)한국패시브건축협회(PHIKO) "우리나라 년도별 단열성능의 변화"
(https://www.phiko.kr/bbs/board.php?bo_table=z3_01&wr_id=347) 에서 고시
원문 발췌 확인 — 국가법령정보센터 원문과 대조 가능한 표만 사용.
- 2010년 에너지절약설계기준 개정(2010.11.5 개정, 2011.2.1 시행) 별표4
- 2012년 에너지절약설계기준 개정(2012.11.30 개정, 2013.9.1 시행) 별표1
- 「건축물의 에너지절약 설계기준」(2017.12.28 개정, 2018.9.1 시행,
  국토교통부고시 제2017-881호) 별표1
- 「건축물의 에너지절약설계기준」(국토교통부고시 제2023-104호) 별표1
  (seed_target_u_values.py에서 이미 시드한 reference_document 재사용)

⚠️ 정정 (2026-09-11): 이전 버전은 "2016_2023"(0.260) / "2023_present"
(0.240)로 시드했으나, PHIKO 자료로 확인한 결과 2023-104호는 2018.9.1
시행 기준에서 외벽·창호 목표 U값을 바꾸지 않았다 — 실제 값 변경 시점은
2018.9.1이었다. 잘못된 구간 키를 삭제하고 실제 시행일 기준으로 재시드한다.

⚠️ 범위 제한 (임의로 채우지 않음, 계속 유지):
- 2011.2.1 이전(2001~2010년 기준)은 다루지 않는다. 그 이전 고시는
  U값을 직접 명시하지 않고 "단열재 두께 몇 mm 이상"으로만 규정해서,
  U값으로 환산하려면 단열재 종류별 열전도율 가정이 필요해 정확도가
  떨어진다. PHIKO 댓글 스레드에서도 "2001~2010년은 기준 변화 없음"이라고
  확인됨 — 이 구간 전체가 두께 기반이라 여전히 미해결이다.
- current_wall_u_value_policies의 building_group(공동주택/공동주택외)
  구분이 스키마에 없어(construction_year_range × insulation_status만
  조회 키), 2016.7 이후 구간은 "공동주택 외"(단독·다가구주택에 가까운,
  더 완화된) 값을 대표값으로 채택했다 — 2016.7 이전 구간은 애초에 고시
  자체가 공동주택/공동주택외를 구분하지 않아 그 고민이 없다.
- insulation_status는 "양호"(그 시기 법정 기준을 지킨 경우)만 채운다.
  "부분"/"없음"에 대응하는 실제 수치 근거를 찾지 못했으므로 임의로 만들지
  않고 비워둔다 — 계산 시 REFERENCE_DATA_MISSING으로 정직하게 막힌다.

실행: python -m app.db.seed.seed_construction_year_wall_u (재실행해도 안전)
"""

from datetime import date

from sqlalchemy import delete, select

from app.db.session import SessionLocal
from app.models.building import ConstructionYearRange, InsulationStatus
from app.models.reference_document import ReferenceDocument
from app.models.u_value_policy import CurrentWallUValuePolicy

_POLICY_VERSION = "construction-year-v2"

# 2026-09-11 정정 이전에 잘못된 시행일 경계로 시드했던 키 — 있으면 지운다.
_OBSOLETE_YEAR_RANGE_KEYS = ["2016_2023", "2023_present"]

_YEAR_RANGES = [
    # key, label, start_year, end_year
    ("2011_2013", "2011년 2월 ~ 2013년 8월", 2011, 2013),
    ("2013_2016", "2013년 9월 ~ 2016년 6월", 2013, 2016),
    ("2016_2018", "2016년 7월 ~ 2018년 8월", 2016, 2018),
    ("2018_present", "2018년 9월 이후", 2018, None),
]

_INSULATION_STATUSES = [
    ("none", "단열 없음/모름"),
    ("partial", "부분 단열"),
    ("good", "양호"),
]

# 중부지역/중부2지역, 외기 직접 면하는 경우 — W/m2K.
# 2016.7 이전 고시는 공동주택/공동주택외 구분이 없어 단일값 그대로 사용.
# 2016.7 이후는 "공동주택 외"(단독·다가구 근사치) 값을 채택 — 창호와 동일한 이유.
_WALL_U_BY_YEAR_RANGE = {
    "2011_2013": 0.36,
    "2013_2016": 0.270,
    "2016_2018": 0.260,
    "2018_present": 0.240,
}

_REFERENCE_DOCS = {
    "2011_2013": {
        "reference_name": "건축물의 에너지절약설계기준",
        "reference_version": "2010년 개정(2011.2.1 시행)",
        "notice_number": None,
        "effective_date": date(2011, 2, 1),
        "source_document": (
            "PHIKO(한국패시브건축협회) '우리나라 년도별 단열성능의 변화' 정리글에서 원문 발췌 확인, "
            "2010년 에너지절약설계기준 개정(2010.11.5 개정) 별표4"
        ),
    },
    "2013_2016": {
        "reference_name": "건축물의 에너지절약설계기준",
        "reference_version": "2012년 개정(2013.9.1 시행)",
        "notice_number": None,
        "effective_date": date(2013, 9, 1),
        "source_document": (
            "PHIKO(한국패시브건축협회) '우리나라 년도별 단열성능의 변화' 정리글에서 원문 발췌 확인, "
            "2012년 에너지절약설계기준 개정(2012.11.30 개정) 별표1"
        ),
    },
    "2016_2018": {
        "reference_name": "건축물의 에너지절약 설계기준",
        "reference_version": "제2015-1108호",
        "notice_number": "국토교통부고시 제2015-1108호",
        "effective_date": date(2016, 7, 1),
        "source_document": (
            "PHIKO(한국패시브건축협회) '우리나라 년도별 단열성능의 변화' 정리글에서 원문 발췌 확인, "
            "별표1(지역별 건축물 부위의 열관류율표) 부칙: 별표1·별표3은 2016.7.1 시행"
        ),
    },
    "2018_present": {
        "reference_name": "건축물의 에너지절약 설계기준",
        "reference_version": "제2017-881호",
        "notice_number": "국토교통부고시 제2017-881호",
        "effective_date": date(2018, 9, 1),
        "source_document": (
            "PHIKO(한국패시브건축협회) '우리나라 년도별 단열성능의 변화' 정리글에서 원문 발췌 확인 — "
            "2023-104호까지 이 값(중부2지역 공동주택외 0.240) 그대로 유지됨을 대조 확인"
        ),
    },
}


def _get_or_create_reference_document(db, key: str) -> ReferenceDocument:
    spec = _REFERENCE_DOCS[key]
    doc = db.scalar(
        select(ReferenceDocument).where(
            ReferenceDocument.reference_name == spec["reference_name"],
            ReferenceDocument.reference_version == spec["reference_version"],
        )
    )
    if doc is None:
        doc = ReferenceDocument(
            reference_name=spec["reference_name"],
            notice_number=spec["notice_number"],
            reference_version=spec["reference_version"],
            effective_date=spec["effective_date"],
            source_document=spec["source_document"],
        )
        db.add(doc)
        db.flush()
        print(f"reference_documents 추가: {doc.reference_name} {doc.reference_version}")
    return doc


def seed_construction_year_wall_u() -> None:
    db = SessionLocal()
    try:
        # 잘못된 시행일 경계로 들어간 예전 구간 정리
        for obsolete_key in _OBSOLETE_YEAR_RANGE_KEYS:
            deleted_policies = db.execute(
                delete(CurrentWallUValuePolicy).where(
                    CurrentWallUValuePolicy.construction_year_range_key == obsolete_key
                )
            )
            if deleted_policies.rowcount:
                print(f"current_wall_u_value_policies 삭제(구버전 구간): {obsolete_key} x{deleted_policies.rowcount}")
            deleted_range = db.execute(
                delete(ConstructionYearRange).where(
                    ConstructionYearRange.construction_year_range_key == obsolete_key
                )
            )
            if deleted_range.rowcount:
                print(f"construction_year_ranges 삭제(구버전 구간): {obsolete_key}")

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

        for range_key, u_value in _WALL_U_BY_YEAR_RANGE.items():
            doc = _get_or_create_reference_document(db, range_key)
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
                        reference_document_id=doc.reference_document_id,
                    )
                )
                print(f"current_wall_u_value_policies 추가: {range_key}/good = {u_value}")

        db.commit()
        print("완료.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_construction_year_wall_u()
