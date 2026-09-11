import Foundation

/// GET /api/v1/regions — region_id를 사람이 읽을 수 있는 지역명으로 바꾸는 데
/// 쓴다. 인증 불필요(공개 기준 데이터).
enum ReferenceAPI {
    struct RegionItem: Decodable {
        let region_id: String
        let display_name: String
    }

    private struct RegionsResponse: Decodable {
        let regions: [RegionItem]
    }

    static func regions() async throws -> [RegionItem] {
        let response: RegionsResponse = try await APIClient.request(path: "/api/v1/regions")
        return response.regions
    }

    struct ConstructionYearRangeOption: Decodable, Hashable {
        let value: String
        let label: String
    }

    struct OptionItem: Decodable, Hashable {
        let value: String
        let label: String
    }

    /// window_type_options, low_e_options, wall_visible_anomaly_confirm_options는
    /// 서버 코드에서도 DB가 아니라 고정 상수로 두는 값이라(reference.py의
    /// REPRESENTATIVE_SPACE_TYPES 등) 여기서도 아직 쓰는 화면이 생길 때까지
    /// 디코딩 대상에 넣지 않는다 — JSONDecoder는 모르는 필드를 그냥 무시한다.
    private struct ReferenceOptionsResponse: Decodable {
        let building_types: [OptionItem]
        let construction_year_ranges: [ConstructionYearRangeOption]
        let wall_insulation_status_options: [OptionItem]
    }

    private static var cachedOptions: ReferenceOptionsResponse?

    private static func options() async throws -> ReferenceOptionsResponse {
        if let cachedOptions { return cachedOptions }
        let response: ReferenceOptionsResponse = try await APIClient.request(path: "/api/v1/reference/options")
        cachedOptions = response
        return response
    }

    static func constructionYearRanges() async throws -> [ConstructionYearRangeOption] {
        try await options().construction_year_ranges
    }

    /// db-spec.md 기준 DB 시드 데이터(building_type_target_group_mappings)를
    /// 그대로 받는다 — 현재는 "단독·다가구주택"/"아파트" 2개.
    static func buildingTypes() async throws -> [OptionItem] {
        try await options().building_types
    }

    /// insulation_statuses 테이블 시드 데이터 그대로. "부분"/"없음"은 U값
    /// 근거 데이터가 없어 계산 시 REFERENCE_DATA_MISSING으로 막히지만(db-spec.md
    /// 8장), 선택지 자체는 서버가 실제로 아는 값이라 그대로 보여준다.
    static func wallInsulationStatusOptions() async throws -> [OptionItem] {
        try await options().wall_insulation_status_options
    }
}

/// PRD v7 2.1: 대표 공간은 이 3종 중 하나. 서버(reference.py의
/// REPRESENTATIVE_SPACE_TYPES)도 DB가 아니라 코드 상수로 두는 고정값이라
/// 여기서도 그대로 고정값으로 둔다.
enum RepresentativeSpaceType {
    static let options: [ReferenceAPI.OptionItem] = [
        .init(value: "living_room", label: "거실"),
        .init(value: "main_bedroom", label: "주침실"),
        .init(value: "other", label: "기타 대표 공간"),
    ]
}
