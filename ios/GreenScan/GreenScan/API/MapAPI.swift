import Foundation

/// GET /api/v1/map/geocode — 카카오맵으로 주소를 좌표로 바꾸고 서울 지원
/// 지역 여부를 판별한다(api-spec.md 1.1: 로그인 필요 엔드포인트).
enum MapAPI {
    struct GeocodeResponse: Decodable {
        let region_id: String
        let hdd_lookup_key: String
        let latitude: Double
        let longitude: Double
        let road_address: String?
    }

    static func geocode(address: String, token: String) async throws -> GeocodeResponse {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        return try await APIClient.request(
            path: "/api/v1/map/geocode?address=\(encoded)",
            token: token
        )
    }
}
