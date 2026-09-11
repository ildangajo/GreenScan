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

    // 사진업로드/AI확인 화면에서 채움
    var windowTypeConfirmed = "double"
    var lowE = "unknown"
    var anomalyConfirmed = "none_observed"

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
        windowTypeConfirmed = "double"
        lowE = "unknown"
        anomalyConfirmed = "none_observed"
    }
}

/// HomeView의 NavigationStack이 갖는 경로. 결과 화면("진단 종료")처럼 여러
/// 단계 뒤에서 한 번에 홈으로 돌아가야 하는 경우, dismiss()는 한 단계씩만
/// pop하므로 쓸 수 없다 — 이 path를 공유해서 직접 비우면 즉시 루트로 돌아간다.
@Observable
final class DiagnosisNavigationPath {
    var path = NavigationPath()
}
