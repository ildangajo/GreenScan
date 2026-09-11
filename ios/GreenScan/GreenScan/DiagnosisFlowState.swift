import SwiftUI

/// 웹 state/DiagnosisContext.tsx의 포팅. AI 진단 시작(주소/연도) → 건물유형/
/// 대표공간 → 공간치수 → 사진업로드/AI확인 → 결과 화면까지 여러 화면이
/// 공유하는 진단 입력 상태다.
///
/// 값들은 실제 계산 API 계약(backend/app/schemas/diagnosis.py CalculateRequest,
/// api-spec.md 2.4)의 enum 문자열과 정확히 같은 값을 쓴다 — ResultView가 이
/// 상태를 그대로 CalculateAPI.CalculateRequest로 조립해 POST
/// /diagnoses/calculate를 부른다. 필드명이 백엔드와 달라도(예:
/// constructionYearRange → construction_year_range) *값*만 정확히 일치하면
/// 되고, 조립 단계에서 필드명을 매핑한다.
@Observable
final class DiagnosisFlowState {
    // AiDiagnosisView에서 채움
    var address = ""
    var regionId = ""
    var constructionYearRange = ""

    // BuildingSpaceSelectView에서 채움
    var buildingType = "apartment"
    var spaceType = "living_room"

    // SpaceInputView에서 채움
    var width = ""
    var depth = ""
    var height = ""
    var floorArea = ""
    var windowArea = ""
    var wallArea = ""
    var insulationStatus = ""
    /// 문 합산면적(m²) — 선택 입력. 빈 문자열이면 CalculateRequest.Space에
    /// door_area_m2 자체를 안 실어 보내고(옵셔널) 백엔드 기본값(2.0㎡)이
    /// 적용된다(backend/app/schemas/diagnosis.py SpaceInput). 라이다 스캔이
    /// 문을 감지하면 자동으로 채워진다(RoomScanView) — spaceInputSource와
    /// 같은 출처 추적을 공유한다(문도 SpaceInput 블록 소속).
    var doorArea = ""

    /// 가로/세로/높이/바닥면적의 출처 — "manual"(직접 입력) | "lidar"(스캔
    /// 그대로) | "user_corrected"(스캔값을 사용자가 다시 고침). 계산 API의
    /// window/wall input_source는 창호유형·Low-E·단열상태처럼 라이다로는
    /// 절대 못 얻는 값을 항상 같이 포함하고 있어서 그쪽은 그대로
    /// "user_corrected" 고정으로 둔다(ResultView 참고) — 여기서 추적하는 건
    /// 순수 치수(SpaceInput) 블록 하나뿐이다.
    var spaceInputSource = "manual"

    // 사진업로드/AI확인 화면에서 채움
    var windowTypeConfirmed = "double"
    var lowE = "unknown"
    var anomalyConfirmed = "none_observed"

    // SurveyView(AI 분석하기 전 설문, PM 지시로 2026-09-12에 실측 연계형으로
    // 개편)에서 채움. v2부터는 설문 답 대부분이 "참고용 별도 저장"이 아니라
    // building/space/window/wall 실제 계산 필드에 곧바로 반영된다(설문 =
    // 사전 필터, 뒤 화면들이 그 값을 미리 선택된 상태로 보여주고 사용자가
    // 다시 확인/수정할 수 있다). 계산에 영향을 주면 안 된다고 팀이 합의한
    // "불편한 점"만 여전히 confirmed_input 스냅샷 전용으로 남는다(±15% 같은
    // 임의 보정 금지 — 2026-09-12 팀 리뷰 결론).
    var surveyDiscomforts: Set<String> = []

    /// 결과 화면에서 "진단 종료"를 누르면 홈으로 돌아가면서 호출한다 —
    /// 다음 진단이 이전 값을 이어받지 않도록 초기 상태로 되돌린다.
    func reset() {
        address = ""
        regionId = ""
        constructionYearRange = ""
        buildingType = "apartment"
        spaceType = "living_room"
        width = ""
        depth = ""
        height = ""
        floorArea = ""
        windowArea = ""
        wallArea = ""
        insulationStatus = ""
        doorArea = ""
        spaceInputSource = "manual"
        windowTypeConfirmed = "double"
        lowE = "unknown"
        anomalyConfirmed = "none_observed"
        surveyDiscomforts = []
    }
}

/// HomeView의 NavigationStack이 갖는 경로. 결과 화면("진단 종료")처럼 여러
/// 단계 뒤에서 한 번에 홈으로 돌아가야 하는 경우, dismiss()는 한 단계씩만
/// pop하므로 쓸 수 없다 — 이 path를 공유해서 직접 비우면 즉시 루트로 돌아간다.
@Observable
final class DiagnosisNavigationPath {
    var path = NavigationPath()
}
