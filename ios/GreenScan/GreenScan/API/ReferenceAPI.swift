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

    /// 응답의 다른 필드(building_types, window_type_options 등)는 아직 쓰는
    /// 화면이 없어서 여기 선언하지 않는다 — JSONDecoder는 모르는 필드를
    /// 그냥 무시하므로 디코딩엔 문제없다. 필요해지면 그때 추가한다.
    private struct ReferenceOptionsResponse: Decodable {
        let construction_year_ranges: [ConstructionYearRangeOption]
    }

    static func constructionYearRanges() async throws -> [ConstructionYearRangeOption] {
        let response: ReferenceOptionsResponse = try await APIClient.request(path: "/api/v1/reference/options")
        return response.construction_year_ranges
    }
}
