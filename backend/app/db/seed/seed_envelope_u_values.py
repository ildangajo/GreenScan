"""천장/바닥/문 현재 U값 시드 (calc-v2, docs/result-screen-v9-design.md 2절).

⚠️ 이 파일의 수치는 seed_construction_year_wall_u.py(PHIKO·국토부 고시
원문 대조 확인)와 **다른 신뢰도**다. 같은 고시(에너지절약설계기준 별표1)가
지붕·바닥·문도 같은 표에서 규정한다는 공학적 통념과, 벽체 대비 일반적인
비율(지붕은 벽체보다 약간 엄격, 바닥은 약간 완화, 문은 비Low-E 창호와
비슷한 수준)로 추정한 **잠정값**이다 — 원문을 직접 대조하지 않았다.
policy_version에 "-unverified"를 붙여 구분해뒀고, reference_document의
source_document에도 이 사실을 그대로 적어둔다. 원문 대조가 끝나면 이
파일을 실측값으로 갈아끼우고 "-unverified" 접미사를 뗀다.

연식 구간 키는 seed_construction_year_wall_u.py와 동일한
construction_year_ranges를 그대로 재사용한다(그 시드가 먼저 실행돼 있어야
함 — construction_year_range_key FK 제약).

실행: python -m app.db.seed.seed_envelope_u_values (재실행해도 안전)
"""

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.envelope_u_value_policy import (
    CurrentCeilingUValuePolicy,
    CurrentDoorUValuePolicy,
    CurrentFloorUValuePolicy,
)
from app.models.reference_document import ReferenceDocument

_POLICY_VERSION = "envelope-estimate-v1-unverified"

_REFERENCE_SPEC = {
    "reference_name": "건축물의 에너지절약 설계기준 별표1 (천장·바닥·문 추정치)",
    "reference_version": "engineering-estimate-v1-unverified",
    "notice_number": None,
    "effective_date": None,
    "source_document": (
        "⚠️ 원문 미대조 잠정값. seed_construction_year_wall_u.py가 확인한 같은 별표1이 "
        "지붕/바닥/문 열관류율도 같이 규정한다는 통념에 기반해, 벽체 값 대비 일반적인 "
        "비율(지붕 0.9배, 바닥 1.15배)과 통상적인 문 성능 수준으로 추정했다. "
        "실제 원문 대조 전까지 계산에 참고용으로만 쓴다."
    ),
}

# construction_year_range_key -> u_value_w_m2k
_CEILING_U_BY_YEAR_RANGE = {
    "2011_2013": 0.32,
    "2013_2016": 0.24,
    "2016_2018": 0.22,
    "2018_present": 0.15,
}

_FLOOR_U_BY_YEAR_RANGE = {
    "2011_2013": 0.41,
    "2013_2016": 0.35,
    "2016_2018": 0.30,
    "2018_present": 0.25,
}

_DOOR_U_BY_YEAR_RANGE = {
    "2011_2013": 2.9,
    "2013_2016": 2.7,
    "2016_2018": 2.4,
    "2018_present": 1.9,
}


def _get_or_create_reference_document(db) -> ReferenceDocument:
    doc = db.scalar(
        select(ReferenceDocument).where(
            ReferenceDocument.reference_name == _REFERENCE_SPEC["reference_name"],
            ReferenceDocument.reference_version == _REFERENCE_SPEC["reference_version"],
        )
    )
    if doc is None:
        doc = ReferenceDocument(
            reference_name=_REFERENCE_SPEC["reference_name"],
            notice_number=_REFERENCE_SPEC["notice_number"],
            reference_version=_REFERENCE_SPEC["reference_version"],
            effective_date=_REFERENCE_SPEC["effective_date"],
            source_document=_REFERENCE_SPEC["source_document"],
        )
        db.add(doc)
        db.flush()
    return doc


def _upsert(db, model, year_range_key: str, u_value: float, reference_document_id, unique_where) -> None:
    existing = db.scalar(select(model).where(*unique_where))
    if existing:
        existing.u_value_w_m2k = u_value
        existing.reference_document_id = reference_document_id
    else:
        db.add(
            model(
                construction_year_range_key=year_range_key,
                u_value_w_m2k=u_value,
                policy_version=_POLICY_VERSION,
                reference_document_id=reference_document_id,
            )
        )


def seed_envelope_u_values() -> None:
    with SessionLocal() as db:
        doc = _get_or_create_reference_document(db)

        for year_key, u_value in _CEILING_U_BY_YEAR_RANGE.items():
            _upsert(
                db,
                CurrentCeilingUValuePolicy,
                year_key,
                u_value,
                doc.reference_document_id,
                (
                    CurrentCeilingUValuePolicy.construction_year_range_key == year_key,
                    CurrentCeilingUValuePolicy.policy_version == _POLICY_VERSION,
                ),
            )

        for year_key, u_value in _FLOOR_U_BY_YEAR_RANGE.items():
            _upsert(
                db,
                CurrentFloorUValuePolicy,
                year_key,
                u_value,
                doc.reference_document_id,
                (
                    CurrentFloorUValuePolicy.construction_year_range_key == year_key,
                    CurrentFloorUValuePolicy.policy_version == _POLICY_VERSION,
                ),
            )

        for year_key, u_value in _DOOR_U_BY_YEAR_RANGE.items():
            _upsert(
                db,
                CurrentDoorUValuePolicy,
                year_key,
                u_value,
                doc.reference_document_id,
                (
                    CurrentDoorUValuePolicy.construction_year_range_key == year_key,
                    CurrentDoorUValuePolicy.policy_version == _POLICY_VERSION,
                ),
            )

        db.commit()
        print(f"천장/바닥/문 U값 시드 완료 (policy_version={_POLICY_VERSION})")


if __name__ == "__main__":
    seed_envelope_u_values()
