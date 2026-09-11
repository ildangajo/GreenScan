"""천장/바닥/문 현재 U값 시드 (calc-v2, docs/result-screen-v9-design.md 2절).

2026-09-12 갱신: 2016_2018/2018_present 두 구간은 국가법령정보센터에서
받은 실제 개정고시 원문(PDF)으로 원문 대조 확인했다 — 국토교통부고시
제2017-881호(2018.9.1 시행) 신·구조문대비표에 "현행"(제2015-1108호,
2016.7.1 시행)과 "개정안"(제2017-881호) 별표1 전문이 나란히 실려있어서
두 시기 모두 한 번에 확인됐다. seed_construction_year_wall_u.py가 벽체에
쓴 것과 같은 고시들이다.

⚠️ 2011_2013/2013_2016 두 구간은 여전히 미대조 잠정값이다 — 이 두 구간을
규정하는 2010년 개정(2011.2.1 시행)/2012년 개정(2013.9.1 시행) 원문은
이번에 못 구했다(PHIKO 정리글이 보안 인증에 막혀 직접 열람 불가, 원문
PDF도 아직 못 찾음). 벽체 값 대비 일반적인 비율로 추정한 값을 그대로
쓰고 policy_version에 "-unverified"를 유지한다.

문(門)은 흥미롭게도 두 시기 모두 같은 값(1.4/1.8, 공동주택 세대현관문
및 방화문 기준)이라 시기 구분 없이 동일하게 쓴다 — 이전 추정치(2.4~2.9)는
크게 부정확했다(일반 비Low-E 창호 수준으로 추정했는데, 실제 고시는 문을
훨씬 더 낮은 U값으로 규정한다).

지붕/바닥은 '공동주택'/'공동주택 외' 구분이 없다(창호·벽체와 달리) —
region만 있으면 된다. 벽체 시드가 쓴 것과 같은 대표 지역(중부/중부2지역,
2016.7 이전엔 지역 구분 자체가 3개(중부/남부/제주) 뿐이라 그중 중부)을
그대로 쓴다. 바닥은 "바닥난방인 경우, 외기에 직접 면하는 경우"만 쓴다
(우리나라 주거는 온돌/바닥난방이 일반적이라 대표값으로 적절).

연식 구간 키는 seed_construction_year_wall_u.py와 동일한
construction_year_ranges를 그대로 재사용한다(그 시드가 먼저 실행돼 있어야
함 — construction_year_range_key FK 제약).

실행: python -m app.db.seed.seed_envelope_u_values (재실행해도 안전)
"""

from datetime import date

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.envelope_u_value_policy import (
    CurrentCeilingUValuePolicy,
    CurrentDoorUValuePolicy,
    CurrentFloorUValuePolicy,
)
from app.models.reference_document import ReferenceDocument

_POLICY_VERSION_ESTIMATE = "envelope-estimate-v1-unverified"
_POLICY_VERSION_VERIFIED = "envelope-v2-verified"

# 새로 검증된 두 구간이 예전 미검증 버전으로 이미 시드돼 있을 수 있다 —
# 그 행은 지우고 검증본으로 새로 넣는다(같은 policy_version이 아니라서
# _upsert만으로는 안 지워짐, wall 시드의 obsolete-key 정리와 같은 이유).
_NEWLY_VERIFIED_YEAR_RANGE_KEYS = ["2016_2018", "2018_present"]

# construction_year_range_key -> u_value_w_m2k, 검증 여부별로 나눔.
_CEILING_ESTIMATE_BY_YEAR_RANGE = {
    "2011_2013": 0.32,
    "2013_2016": 0.24,
}
_CEILING_VERIFIED_BY_YEAR_RANGE = {
    "2016_2018": 0.150,  # 제2015-1108호 별표1, 중부지역, 외기 직접
    "2018_present": 0.150,  # 제2017-881호 별표1, 중부1·중부2지역(같은 값), 외기 직접
}

_FLOOR_ESTIMATE_BY_YEAR_RANGE = {
    "2011_2013": 0.41,
    "2013_2016": 0.35,
}
_FLOOR_VERIFIED_BY_YEAR_RANGE = {
    "2016_2018": 0.180,  # 제2015-1108호, 중부지역, 바닥난방·외기 직접
    "2018_present": 0.170,  # 제2017-881호, 중부2지역, 바닥난방·외기 직접
}

_DOOR_ESTIMATE_BY_YEAR_RANGE = {
    "2011_2013": 2.9,
    "2013_2016": 2.7,
}
_DOOR_VERIFIED_BY_YEAR_RANGE = {
    # 공동주택 세대현관문 및 방화문, 외기 직접 — 제2015-1108호/제2017-881호 둘 다 동일값.
    "2016_2018": 1.400,
    "2018_present": 1.400,
}

_ESTIMATE_REFERENCE_SPEC = {
    "reference_name": "건축물의 에너지절약 설계기준 별표1 (천장·바닥·문 추정치)",
    "reference_version": "engineering-estimate-v1-unverified",
    "notice_number": None,
    "effective_date": None,
    "source_document": (
        "⚠️ 원문 미대조 잠정값(2011_2013/2013_2016 구간만 남음 — 2016_2018/"
        "2018_present는 실제 고시 원문으로 검증 완료, 아래 verified 참조문서 참고). "
        "같은 고시(에너지절약설계기준 별표1)가 지붕/바닥/문 열관류율도 같이 규정한다는 "
        "통념에 기반해, 벽체 값 대비 일반적인 비율(지붕 0.9배, 바닥 1.15배)과 통상적인 "
        "문 성능 수준으로 추정했다."
    ),
}

_VERIFIED_REFERENCE_SPECS = {
    "2016_2018": {
        "reference_name": "건축물의 에너지절약 설계기준",
        "reference_version": "제2015-1108호",
        "notice_number": "국토교통부고시 제2015-1108호",
        "effective_date": date(2016, 7, 1),
        "source_document": (
            "국토교통부 「건축물의 에너지절약설계기준」 일부개정고시안(2017년 개정, "
            "제2017-881호) 신·구조문대비표의 '현행'(제2015-1108호, 2016.7.1 시행) "
            "별표1 원문 — 지붕(중부 0.150)/바닥(중부, 바닥난방·외기직접 0.180)/공동주택 "
            "세대현관문(외기직접 1.400). seed_construction_year_wall_u.py의 같은 "
            "구간(2016_2018) reference_document와 동일 고시."
        ),
    },
    "2018_present": {
        "reference_name": "건축물의 에너지절약 설계기준",
        "reference_version": "제2017-881호",
        "notice_number": "국토교통부고시 제2017-881호",
        "effective_date": date(2018, 9, 1),
        "source_document": (
            "국토교통부 「건축물의 에너지절약설계기준」 일부개정고시안(2017년 개정, "
            "제2017-881호, 2018.9.1 시행) 별표1 개정안 원문 — 지붕(중부1·중부2 0.150)/"
            "바닥(중부2, 바닥난방·외기직접 0.170)/공동주택 세대현관문(외기직접 1.400). "
            "seed_construction_year_wall_u.py의 같은 구간(2018_present) "
            "reference_document와 동일 고시."
        ),
    },
}


def _get_or_create_reference_document(db, spec: dict) -> ReferenceDocument:
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
    return doc


def _delete_obsolete_estimate_rows(db, model) -> None:
    """새로 검증된 구간에 남아있을 수 있는 예전 미검증 행을 지운다."""
    for year_key in _NEWLY_VERIFIED_YEAR_RANGE_KEYS:
        stale = db.scalar(
            select(model).where(
                model.construction_year_range_key == year_key,
                model.policy_version == _POLICY_VERSION_ESTIMATE,
            )
        )
        if stale:
            db.delete(stale)


def _upsert(db, model, year_range_key: str, u_value: float, policy_version: str, reference_document_id) -> None:
    existing = db.scalar(
        select(model).where(
            model.construction_year_range_key == year_range_key,
            model.policy_version == policy_version,
        )
    )
    if existing:
        existing.u_value_w_m2k = u_value
        existing.reference_document_id = reference_document_id
    else:
        db.add(
            model(
                construction_year_range_key=year_range_key,
                u_value_w_m2k=u_value,
                policy_version=policy_version,
                reference_document_id=reference_document_id,
            )
        )


def seed_envelope_u_values() -> None:
    with SessionLocal() as db:
        estimate_doc = _get_or_create_reference_document(db, _ESTIMATE_REFERENCE_SPEC)
        verified_docs = {
            year_key: _get_or_create_reference_document(db, spec)
            for year_key, spec in _VERIFIED_REFERENCE_SPECS.items()
        }

        for model in (CurrentCeilingUValuePolicy, CurrentFloorUValuePolicy, CurrentDoorUValuePolicy):
            _delete_obsolete_estimate_rows(db, model)

        for year_key, u_value in _CEILING_ESTIMATE_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentCeilingUValuePolicy, year_key, u_value,
                _POLICY_VERSION_ESTIMATE, estimate_doc.reference_document_id,
            )
        for year_key, u_value in _CEILING_VERIFIED_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentCeilingUValuePolicy, year_key, u_value,
                _POLICY_VERSION_VERIFIED, verified_docs[year_key].reference_document_id,
            )

        for year_key, u_value in _FLOOR_ESTIMATE_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentFloorUValuePolicy, year_key, u_value,
                _POLICY_VERSION_ESTIMATE, estimate_doc.reference_document_id,
            )
        for year_key, u_value in _FLOOR_VERIFIED_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentFloorUValuePolicy, year_key, u_value,
                _POLICY_VERSION_VERIFIED, verified_docs[year_key].reference_document_id,
            )

        for year_key, u_value in _DOOR_ESTIMATE_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentDoorUValuePolicy, year_key, u_value,
                _POLICY_VERSION_ESTIMATE, estimate_doc.reference_document_id,
            )
        for year_key, u_value in _DOOR_VERIFIED_BY_YEAR_RANGE.items():
            _upsert(
                db, CurrentDoorUValuePolicy, year_key, u_value,
                _POLICY_VERSION_VERIFIED, verified_docs[year_key].reference_document_id,
            )

        db.commit()
        print(
            "천장/바닥/문 U값 시드 완료 "
            f"(2011_2013/2013_2016={_POLICY_VERSION_ESTIMATE}, "
            f"2016_2018/2018_present={_POLICY_VERSION_VERIFIED})"
        )


if __name__ == "__main__":
    seed_envelope_u_values()
