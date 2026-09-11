"""HDD, 지원 지역 기준 데이터 시드.

출처: KOSIS 국가통계포털 "냉난방도일" (에너지경제연구원, 에너지수급통계).
https://stat.kosis.kr - 2026-09-11 사용자가 직접 조회해 내려받은 2023.01~
2023.12 월별 난방도일 합산.

⚠️ 중요한 한계 (임의로 감추지 않고 명시): 이 통계는 **전국 평균**이다.
KOSIS 조회 화면에 지역(서울 등) 구분 옵션이 없음을 2026-09-11 직접 확인함.
즉 서울 관측소 전용 HDD가 아니라 전국 평균치를 서울/김포의 근사값으로
쓰는 것이다. 서울 전용 관측치(기상청 기후정보포털 등)를 찾으면 이 값을
교체해야 한다 — db-spec.md 8장에 미해결 항목으로 계속 남겨둔다.

실행: python -m app.db.seed.seed_hdd_regions (재실행해도 안전)
"""

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.reference_document import ReferenceDocument
from app.models.region import HddValue, SupportedRegion

_HDD_REFERENCE_NAME = "냉난방도일 통계 (KOSIS, 에너지경제연구원)"
_HDD_REFERENCE_VERSION = "2023년 연간"

# 2023.01~12 난방도일(도일) 합산: 605.2+439.6+254.8+128.9+17.8+0+0+0+0+69.0+341.4+523.4
_HDD_VALUE_K_DAY = 2380.1
_HDD_LOOKUP_KEY = "seoul"

_CLIMATE_ZONE_KEY = "jungbu-2"
_REGION_DATA_VERSION = "region-seed-v1"


def seed_hdd_regions() -> None:
    db = SessionLocal()
    try:
        doc = db.scalar(
            select(ReferenceDocument).where(
                ReferenceDocument.reference_name == _HDD_REFERENCE_NAME,
                ReferenceDocument.reference_version == _HDD_REFERENCE_VERSION,
            )
        )
        if doc is None:
            doc = ReferenceDocument(
                reference_name=_HDD_REFERENCE_NAME,
                reference_version=_HDD_REFERENCE_VERSION,
                source_document=(
                    "KOSIS(stat.kosis.kr), 통계표 ID DT_F_M530, 에너지경제연구원 에너지수급통계. "
                    "전국 평균치 — 서울 전용 관측 데이터 아님(한계 명시). 자료문의처: 052-714-2165."
                ),
            )
            db.add(doc)
            db.flush()
            print(f"reference_documents 추가: {doc.reference_name}")

        if db.get(HddValue, _HDD_LOOKUP_KEY) is None:
            db.add(
                HddValue(
                    hdd_lookup_key=_HDD_LOOKUP_KEY,
                    hdd_value_k_day=_HDD_VALUE_K_DAY,
                    reference_document_id=doc.reference_document_id,
                )
            )
            print(f"hdd_values 추가: {_HDD_LOOKUP_KEY} = {_HDD_VALUE_K_DAY}")
        db.flush()

        regions = [
            ("seoul", "서울특별시"),
            ("gimpo", "경기도 김포시"),
        ]
        for region_id, display_name in regions:
            if db.get(SupportedRegion, region_id) is None:
                db.add(
                    SupportedRegion(
                        region_id=region_id,
                        display_name=display_name,
                        is_supported=True,
                        hdd_lookup_key=_HDD_LOOKUP_KEY,
                        climate_zone_key=_CLIMATE_ZONE_KEY,
                        region_data_version=_REGION_DATA_VERSION,
                    )
                )
                print(f"supported_regions 추가: {region_id}")

        db.commit()
        print("완료.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_hdd_regions()
