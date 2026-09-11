"""api-spec.md 2.4 `POST /diagnoses/calculate` 요청 검증 스키마.

BE-A 책임(PRD 10장: "공간과 건물의 최종 확정 입력 검증", "계산 요청 조합").
실제 계산 엔진(BE-C)은 아직 이 스키마를 소비하는 엔드포인트를 만들지 않았다 —
이 파일은 그 전에 먼저 확정해야 하는 입력 계약과 검증 규칙만 담는다.
"""

from enum import Enum

from pydantic import BaseModel, model_validator


class InputSource(str, Enum):
    """공간 치수의 출처. 출처와 무관하게 확정된 면적은 같은 계산식을 사용한다."""

    manual = "manual"
    user_corrected = "user_corrected"
    lidar = "lidar"


class ConfirmedInputSource(str, Enum):
    """LiDAR만으로 확정할 수 없는 창호·벽체 복합 입력의 출처."""

    manual = "manual"
    user_corrected = "user_corrected"


class WindowType(str, Enum):
    """AI 후보의 unknown은 계산 입력으로 올 수 없다 — 사용자가 반드시 3개 중 확정."""

    single = "single"
    double = "double"
    triple = "triple"


class LowE(str, Enum):
    yes = "yes"
    no = "no"
    unknown = "unknown"


class InsulationStatus(str, Enum):
    none = "none"
    partial = "partial"
    good = "good"


class VisibleAnomalyConfirmed(str, Enum):
    suspected = "suspected"
    none_observed = "none_observed"


class BuildingInput(BaseModel):
    building_type: str
    representative_space_type: str
    construction_year_range: str


class SpaceInput(BaseModel):
    width_m: float
    depth_m: float
    height_m: float
    floor_area_m2: float
    input_source: InputSource

    @model_validator(mode="after")
    def check_positive_dimensions(self) -> "SpaceInput":
        for field_name in ("width_m", "depth_m", "height_m", "floor_area_m2"):
            if getattr(self, field_name) <= 0:
                raise ValueError(f"{field_name}는 0보다 커야 합니다.")
        return self


class WindowInput(BaseModel):
    total_area_m2: float
    window_type: WindowType
    low_e: LowE
    input_source: ConfirmedInputSource

    @model_validator(mode="after")
    def check_positive_area(self) -> "WindowInput":
        if self.total_area_m2 <= 0:
            raise ValueError("total_area_m2는 0보다 커야 합니다.")
        return self


class WallInput(BaseModel):
    exterior_total_area_m2: float
    insulation_status: InsulationStatus
    visible_anomaly_confirmed: VisibleAnomalyConfirmed
    input_source: ConfirmedInputSource

    @model_validator(mode="after")
    def check_positive_area(self) -> "WallInput":
        if self.exterior_total_area_m2 <= 0:
            raise ValueError("exterior_total_area_m2는 0보다 커야 합니다.")
        return self


class LocationInput(BaseModel):
    region_id: str


class BillInput(BaseModel):
    energy_source: str
    usage_period: str
    usage_amount: float
    unit: str


class WallNetAreaInvalidError(ValueError):
    """error_code: WALL_NET_AREA_INVALID (api-spec.md 2.4, HTTP 422)."""

    def __init__(self, exterior_total_area_m2: float, window_total_area_m2: float):
        self.wall_net_area_m2 = exterior_total_area_m2 - window_total_area_m2
        super().__init__(
            "외기 접촉 벽체 순면적이 0 이하입니다. "
            f"(외기 접촉 벽체 합산면적 {exterior_total_area_m2} - 창호 합산면적 {window_total_area_m2} "
            f"= {self.wall_net_area_m2})"
        )


class CalculateRequest(BaseModel):
    building: BuildingInput
    space: SpaceInput
    window: WindowInput
    wall: WallInput
    location: LocationInput
    bill: BillInput | None = None

    @property
    def wall_net_area_m2(self) -> float:
        return self.wall.exterior_total_area_m2 - self.window.total_area_m2


def check_wall_net_area(request: CalculateRequest) -> float:
    """PRD 5.2 / api-spec.md 2.4: 외기 접촉 벽체 순면적 = 외기 접촉 벽체 합산면적 - 창호 합산면적.

    0 이하면 계산하지 않고 입력 화면으로 되돌린다 (PRD 통합테스트 #6). pydantic
    모델 검증 단계가 아니라 별도 함수로 둔 이유: 이 실패는 api-spec.md가 정의한
    전용 오류 코드(WALL_NET_AREA_INVALID, HTTP 422)로 응답해야 하는데, pydantic
    validator 안에서 raise하면 FastAPI 기본 422 형식(필드 에러 리스트)으로 뭉뚱그려져
    이 코드를 따로 못 붙인다. 계산 엔진(BE-C)이 요청을 파싱한 뒤 이 함수를 호출해
    WallNetAreaInvalidError를 명시적으로 잡아 error_code를 응답에 반영해야 한다.
    """
    net_area = request.wall_net_area_m2
    if net_area <= 0:
        raise WallNetAreaInvalidError(request.wall.exterior_total_area_m2, request.window.total_area_m2)
    return net_area
