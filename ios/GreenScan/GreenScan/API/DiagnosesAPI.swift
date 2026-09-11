import Foundation

/// GET /api/v1/diagnoses, GET /api/v1/diagnoses/{id} — 로그인 계정에 귀속된
/// 과거 진단 이력(db-spec.md 9장, api-spec.md 1.1). 홈 화면 "최근 분석한
/// 건물" 섹션이 이 데이터를 그대로 쓴다 — 목업이 아니라 실제로 사용자가
/// 계산까지 마치고 저장한 진단만 여기 나온다.
enum DiagnosesAPI {
    struct DiagnosisSummary: Decodable, Identifiable {
        let diagnosis_id: UUID
        let building_type_key: String
        let region_id: String
        let created_at: String

        var id: UUID { diagnosis_id }
    }

    private struct DiagnosisListResponse: Decodable {
        let diagnoses: [DiagnosisSummary]
    }

    struct ScenarioResult: Decodable {
        let priority: Int
        let reduction_rate: Double
    }

    struct CalculationResultSnapshot: Decodable {
        let scenarios: [ScenarioResult]
    }

    struct DiagnosisDetail: Decodable {
        let diagnosis_id: UUID
        let calculation_result: CalculationResultSnapshot
    }

    static func list(token: String) async throws -> [DiagnosisSummary] {
        let response: DiagnosisListResponse = try await APIClient.request(
            path: "/api/v1/diagnoses",
            token: token
        )
        return response.diagnoses
    }

    static func detail(id: UUID, token: String) async throws -> DiagnosisDetail {
        try await APIClient.request(path: "/api/v1/diagnoses/\(id.uuidString)", token: token)
    }
}

/// 건물유형 라벨 — 웹 BuildingSpaceSelectPage.tsx의 BUILDING_TYPES와 동일한
/// 고정 2종(db-spec.md: building_types 정책 확정 필요 항목이지만, 이 2개 키는
/// 이미 계산 엔진이 실제로 받는 값이라 여기서도 그대로 하드코딩한다).
enum BuildingTypeLabel {
    static func label(for key: String) -> String {
        switch key {
        case "apartment": return "아파트"
        case "detached_multi_household": return "단독·다가구주택"
        default: return key
        }
    }
}
