import Foundation

/// POST /api/v1/diagnoses/calculate — backend/app/schemas/diagnosis.py
/// CalculateRequest, schemas/calculation.py CalculateResponse와 동일한 계약.
/// PRD 9.1: 로그인 여부와 무관하게 동작한다(인증 헤더 불필요).
enum CalculateAPI {
    struct CalculateRequest: Encodable {
        struct Building: Encodable {
            let building_type: String
            let representative_space_type: String
            let construction_year_range: String
        }
        struct Space: Encodable {
            let width_m: Double
            let depth_m: Double
            let height_m: Double
            let floor_area_m2: Double
            let input_source: String
        }
        struct Window: Encodable {
            let total_area_m2: Double
            let window_type: String
            let low_e: String
            let input_source: String
        }
        struct Wall: Encodable {
            let exterior_total_area_m2: Double
            let insulation_status: String
            let visible_anomaly_confirmed: String
            let input_source: String
        }
        struct Location: Encodable {
            let region_id: String
        }
        /// 계산 계약엔 없는 필드 — /calculate 쪽 백엔드 Pydantic 모델이 알 수
        /// 없는 필드는 조용히 무시한다는 걸 실서버로 직접 확인했다(2026-09-12,
        /// extra 필드를 넣고 200 응답 받음). DiagnosesAPI.create()가 이
        /// CalculateRequest를 그대로 confirmed_input(JSONB, 자유 형식)에 담아
        /// POST /diagnoses로 저장하므로, 여기 끼워두면 계산 자체엔 영향 없이
        /// 설문 응답이 진단 이력에 같이 저장된다 — PM 지시(2026-09-12).
        struct Survey: Encodable {
            let building_category: String
            let discomforts: [String]
            let condition_ratings: [String: Double]
            let preferred_remodels: [String]
        }

        let building: Building
        let space: Space
        let window: Window
        let wall: Wall
        let location: Location
        let survey: Survey
    }

    /// Codable(Decodable만이 아니라 Encodable도)인 이유: DiagnosesAPI.create()가
    /// 계산 응답을 그대로 confirmed_input/calculation_result로 재직렬화해서
    /// POST /diagnoses에 담아 보낸다(test_integration_flow.py의 저장 방식과 동일).
    struct CalculateResponse: Codable {
        struct ReferenceDataVersion: Codable {
            let current_u_value_window: String
            let current_u_value_wall: String
            let target_u_value: String
            let hdd: String
        }
        struct Baseline: Codable {
            let window_heat_loss_kwh: Double
            let wall_heat_loss_kwh: Double
            let total_heat_loss_kwh: Double
        }
        struct Scenario: Codable, Identifiable {
            let scenario_id: String
            let name: String
            let changed_components: [String]
            let annual_reduction_kwh: Double
            let reduction_rate: Double
            let priority: Int

            var id: String { scenario_id }
        }
        struct WallAnomalyNotice: Codable {
            let status: String
            let message: String
        }

        let calculation_version: String
        let reference_data_version: ReferenceDataVersion
        let baseline: Baseline
        let scenarios: [Scenario]
        let wall_anomaly_notice: WallAnomalyNotice
        let unit_scope_disclaimer: String
    }

    /// 실패 시 백엔드가 던지는 error_code: WALL_NET_AREA_INVALID(422),
    /// UNSUPPORTED_REGION(400), INVALID_ENUM_VALUE(400),
    /// REFERENCE_DATA_MISSING(422) — ApiError.code로 구분해서 화면별 안내
    /// 문구를 다르게 보여주면 된다.
    static func calculate(_ payload: CalculateRequest) async throws -> CalculateResponse {
        try await APIClient.request(
            path: "/api/v1/diagnoses/calculate",
            method: "POST",
            body: payload
        )
    }
}
