"""목표/현재 U값 기준 데이터 시드.

출처: 「건축물의 에너지절약설계기준」(국토교통부고시 제2023-104호, 2023.2.28.
시행) 별표1(지역별 건축물 부위의 열관류율표), 별표4(창 및 문의 단열성능).
원문 PDF를 2026-09-11에 직접 확인해 옮긴 값이며, 임의로 추정한 수치가 아니다.

이 스크립트가 채우지 못하는 것 (별도 출처 필요, 아직 미해결):
- HDD 실수치 (별표7은 냉난방 설계 외기온·습도표일 뿐 난방도일이 아님을
  확인함 — 기상청 기후정보포털 또는 한국에너지공단 자료가 별도로 필요)
- construction_year_range의 실제 구간 경계, 그리고 그 구간별 실제 벽체 U값
  (별표1은 신축/개선 목표치 표라 준공연도별 노후 벽체 실측 데이터가 아님)

실행: python -m app.db.seed.seed_target_u_values (여러 번 실행해도 안전 —
이미 있는 policy_version 조합은 건너뛴다)
"""

import uuid
from datetime import date

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.building import BuildingComponent, BuildingTypeTargetGroupMapping, TargetUValueBuildingGroup
from app.models.reference_document import ReferenceDocument
from app.models.region import ClimateZone
from app.models.u_value_policy import CurrentWindowUValuePolicy, TargetUValuePolicy

_POLICY_VERSION = "2023-104-v1"
_APPENDIX_1 = "별표1"
_APPENDIX_4 = "별표4"

# 별표1 비고: 서울특별시는 중부2지역, 경기도 김포시는 중부1지역 예외목록에
# 없어 기본값인 중부2지역에 해당 (원문 대조, 2026-09-11).
_CLIMATE_ZONE_KEY = "jungbu-2"
_CLIMATE_ZONE_LABEL = "중부2지역"
_CLIMATE_ZONE_DESC = (
    "서울특별시, 대전광역시, 세종특별자치시, 인천광역시, 강원도(고성·속초·양양·강릉·동해·삼척), "
    "경기도(연천·포천·가평·남양주·의정부·양주·동두천·파주 제외 — 김포시 포함), "
    "충청북도(제천 제외), 충청남도, 경상북도(봉화·청송·울진·영덕·포항·경주·청도·경산 제외), "
    "전라북도, 경상남도(거창·함양)"
)

# 건축물 기준 그룹
_APARTMENT_GROUP = ("apartment_group", "공동주택")
_NON_APARTMENT_GROUP = ("non_apartment_group", "공동주택 외")

# 부위
_WINDOW_COMPONENT = ("window", "창호")
_WALL_COMPONENT = ("wall", "외기 접촉 벽체")

# 별표1 창 및 문 목표 U값 (중부2지역, 외기에 직접 면하는 경우) — W/m2K
_TARGET_WINDOW_U = {
    "apartment_group": 1.000,
    "non_apartment_group": 1.500,
}

# 별표1 거실 외벽 목표 U값 (중부2지역, 외기에 직접 면하는 경우) — W/m2K
_TARGET_WALL_U = {
    "apartment_group": 0.170,
    "non_apartment_group": 0.240,
}

# 별표4 현재 추정 창호 U값 — 금속재, 열교차단재 미적용, 공기층 12mm 기준.
# (BE-A 판단: 노후주택 실측 데이터가 없어 이 조합을 "낡은 창호"의 보수적
# 근사치로 채택 — 2026-09-11 팀 확인)
# window_type × low_e -> U값
_CURRENT_WINDOW_U = {
    ("single", "no"): 6.10,
    ("single", "yes"): 6.10,
    ("single", "unknown"): 6.10,
    ("double", "no"): 3.4,
    ("double", "yes"): 2.6,
    ("double", "unknown"): 3.4,
    ("triple", "no"): 2.6,
    ("triple", "yes"): 2.0,
    ("triple", "unknown"): 2.6,
}

# 건물유형(사용자 선택) -> 기준그룹 매핑 (PRD 3.1)
_BUILDING_TYPE_MAPPINGS = {
    "detached_multi_household": ("단독·다가구주택", "non_apartment_group"),
    "apartment": ("아파트", "apartment_group"),
}


def seed_target_u_values() -> None:
    db = SessionLocal()
    try:
        doc = db.scalar(
            select(ReferenceDocument).where(
                ReferenceDocument.reference_name == "건축물의 에너지절약설계기준",
                ReferenceDocument.reference_version == "제2023-104호",
            )
        )
        if doc is None:
            doc = ReferenceDocument(
                reference_document_id=uuid.uuid4(),
                reference_name="건축물의 에너지절약설계기준",
                notice_number="국토교통부고시 제2023-104호",
                reference_version="제2023-104호",
                effective_date=date(2023, 2, 28),
                source_document=(
                    "국가법령정보센터 행정규칙, 별표1(지역별 건축물 부위의 열관류율표), "
                    "별표4(창 및 문의 단열성능)"
                ),
            )
            db.add(doc)
            db.flush()
            print(f"reference_documents 추가: {doc.reference_name} {doc.reference_version}")

        if db.get(ClimateZone, _CLIMATE_ZONE_KEY) is None:
            db.add(
                ClimateZone(
                    climate_zone_key=_CLIMATE_ZONE_KEY,
                    display_name=_CLIMATE_ZONE_LABEL,
                    description=_CLIMATE_ZONE_DESC,
                )
            )
            print(f"climate_zones 추가: {_CLIMATE_ZONE_KEY}")

        for key, label in (_APARTMENT_GROUP, _NON_APARTMENT_GROUP):
            if db.get(TargetUValueBuildingGroup, key) is None:
                db.add(TargetUValueBuildingGroup(building_group_key=key, display_name=label))
                print(f"target_u_value_building_groups 추가: {key}")
        db.flush()

        for key, label in (_WINDOW_COMPONENT, _WALL_COMPONENT):
            if db.get(BuildingComponent, key) is None:
                db.add(BuildingComponent(component_key=key, display_name=label))
                print(f"building_components 추가: {key}")
        db.flush()

        for building_type_key, (label, group_key) in _BUILDING_TYPE_MAPPINGS.items():
            if db.get(BuildingTypeTargetGroupMapping, building_type_key) is None:
                db.add(
                    BuildingTypeTargetGroupMapping(
                        building_type_key=building_type_key,
                        display_name=label,
                        building_group_key=group_key,
                    )
                )
                print(f"building_type_target_group_mappings 추가: {building_type_key}")

        db.flush()

        for group_key, u_value in _TARGET_WINDOW_U.items():
            existing = db.scalar(
                select(TargetUValuePolicy).where(
                    TargetUValuePolicy.building_group_key == group_key,
                    TargetUValuePolicy.component_key == "window",
                    TargetUValuePolicy.climate_zone_key == _CLIMATE_ZONE_KEY,
                )
            )
            if existing is None:
                db.add(
                    TargetUValuePolicy(
                        building_group_key=group_key,
                        component_key="window",
                        climate_zone_key=_CLIMATE_ZONE_KEY,
                        appendix_identifier=_APPENDIX_4 + "/" + _APPENDIX_1,
                        condition_description="외기에 직접 면하는 창 및 문, 중부2지역",
                        u_value_w_m2k=u_value,
                        reference_document_id=doc.reference_document_id,
                    )
                )
                print(f"target_u_value_policies(window) 추가: {group_key} = {u_value}")

        for group_key, u_value in _TARGET_WALL_U.items():
            existing = db.scalar(
                select(TargetUValuePolicy).where(
                    TargetUValuePolicy.building_group_key == group_key,
                    TargetUValuePolicy.component_key == "wall",
                    TargetUValuePolicy.climate_zone_key == _CLIMATE_ZONE_KEY,
                )
            )
            if existing is None:
                db.add(
                    TargetUValuePolicy(
                        building_group_key=group_key,
                        component_key="wall",
                        climate_zone_key=_CLIMATE_ZONE_KEY,
                        appendix_identifier=_APPENDIX_1,
                        condition_description="거실의 외벽, 외기에 직접 면하는 경우, 중부2지역",
                        u_value_w_m2k=u_value,
                        reference_document_id=doc.reference_document_id,
                    )
                )
                print(f"target_u_value_policies(wall) 추가: {group_key} = {u_value}")

        for (window_type, low_e), u_value in _CURRENT_WINDOW_U.items():
            existing = db.scalar(
                select(CurrentWindowUValuePolicy).where(
                    CurrentWindowUValuePolicy.window_type_key == window_type,
                    CurrentWindowUValuePolicy.low_e_key == low_e,
                    CurrentWindowUValuePolicy.policy_version == _POLICY_VERSION,
                )
            )
            if existing is None:
                db.add(
                    CurrentWindowUValuePolicy(
                        window_type_key=window_type,
                        low_e_key=low_e,
                        u_value_w_m2k=u_value,
                        policy_version=_POLICY_VERSION,
                        reference_document_id=doc.reference_document_id,
                    )
                )
                print(f"current_window_u_value_policies 추가: {window_type}/{low_e} = {u_value}")

        db.commit()
        print("완료.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_target_u_values()
