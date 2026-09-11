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
}
