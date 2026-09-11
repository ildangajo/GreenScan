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

    /// backend/app/schemas/diagnosis_history.py DiagnosisCreateRequest와 동일한
    /// 계약. confirmed_input/calculation_result는 임의 JSON(dict[str, Any])을
    /// 받는 필드라 계산에 실제로 쓴 요청/응답을 그대로 재직렬화해서 넣는다 —
    /// backend/tests/test_integration_flow.py의 저장 호출부와 같은 방식.
    private struct DiagnosisCreateRequest: Encodable {
        let building_type_key: String
        let region_id: String
        let confirmed_input: CalculateAPI.CalculateRequest
        let calculation_result: CalculateAPI.CalculateResponse
        let calculation_version: String
        let reference_data_version: String
    }

    /// POST /api/v1/diagnoses — 계산 결과를 로그인 계정에 저장한다. 저장 시점
    /// (자동 vs 사용자가 명시적으로 누름)은 PRD상 정책 확정 전이라, 이 함수는
    /// "이미 계산이 끝난 결과를 명시적으로 저장 요청"하는 형태로만 쓴다
    /// (ResultView의 "결과 저장하기" 버튼에서 호출).
    static func create(
        buildingTypeKey: String,
        regionId: String,
        confirmedInput: CalculateAPI.CalculateRequest,
        calculationResult: CalculateAPI.CalculateResponse,
        token: String
    ) async throws -> DiagnosisDetail {
        let referenceDataVersionJSON = try encodeToJSONString(calculationResult.reference_data_version)
        let payload = DiagnosisCreateRequest(
            building_type_key: buildingTypeKey,
            region_id: regionId,
            confirmed_input: confirmedInput,
            calculation_result: calculationResult,
            calculation_version: calculationResult.calculation_version,
            reference_data_version: referenceDataVersionJSON
        )
        return try await APIClient.request(path: "/api/v1/diagnoses", method: "POST", body: payload, token: token)
    }

    private static func encodeToJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
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
