"""GET /regions, GET /reference/options 통합 테스트.

기준 데이터 테이블에서 직접 조회하므로 실제 DB가 필요하다.
test_db_connection.py와 동일하게 RUN_DB_CONNECTION_TEST로 게이팅한다.
"""

import os
import uuid

import pytest
from sqlalchemy import delete

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_CONNECTION_TEST", "").lower() != "true",
    reason="Set RUN_DB_CONNECTION_TEST=true to run reference-data integration tests against a real DB.",
)


@pytest.fixture
def seeded_region():
    from app.db.session import SessionLocal
    from app.models.reference_document import ReferenceDocument
    from app.models.region import ClimateZone, HddValue, SupportedRegion

    db = SessionLocal()
    suffix = uuid.uuid4().hex[:8]
    zone_key = f"zone-{suffix}"
    hdd_key = f"hdd-{suffix}"
    region_id = f"region-{suffix}"

    doc = ReferenceDocument(
        reference_name=f"test-doc-{suffix}",
        reference_version="v1",
        source_document="test",
    )
    zone = ClimateZone(climate_zone_key=zone_key, display_name="테스트 기후구역", description="테스트용")
    db.add_all([doc, zone])
    db.flush()

    hdd = HddValue(hdd_lookup_key=hdd_key, hdd_value_k_day=2500, reference_document_id=doc.reference_document_id)
    db.add(hdd)
    db.flush()

    region = SupportedRegion(
        region_id=region_id,
        display_name="테스트지역",
        is_supported=True,
        hdd_lookup_key=hdd_key,
        climate_zone_key=zone_key,
        region_data_version="test-v1",
    )
    db.add(region)
    db.commit()

    yield region_id

    db.execute(delete(SupportedRegion).where(SupportedRegion.region_id == region_id))
    db.execute(delete(HddValue).where(HddValue.hdd_lookup_key == hdd_key))
    db.execute(delete(ClimateZone).where(ClimateZone.climate_zone_key == zone_key))
    db.execute(delete(ReferenceDocument).where(ReferenceDocument.reference_document_id == doc.reference_document_id))
    db.commit()
    db.close()


def test_get_regions_returns_seeded_supported_region(client, seeded_region):
    response = client.get("/api/v1/regions")

    assert response.status_code == 200
    body = response.json()
    region_ids = {r["region_id"] for r in body["regions"]}
    assert seeded_region in region_ids


def test_get_reference_options_returns_hardcoded_and_db_backed_lists(client):
    response = client.get("/api/v1/reference/options")

    assert response.status_code == 200
    body = response.json()
    # 코드 상수로 둔 목록 — DB에 아무것도 없어도 항상 채워져 있어야 한다.
    assert {"single", "double", "triple"} == {o["value"] for o in body["window_type_options"]}
    assert {"yes", "no", "unknown"} == {o["value"] for o in body["low_e_options"]}
    # DB 기반 목록 — 시드 전이면 빈 리스트일 수 있으나 필드 자체는 항상 존재해야 한다.
    assert isinstance(body["building_types"], list)
    assert isinstance(body["construction_year_ranges"], list)
    assert isinstance(body["wall_insulation_status_options"], list)
