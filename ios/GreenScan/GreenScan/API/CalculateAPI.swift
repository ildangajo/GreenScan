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
            /// 문실측(door_area_m2) — 옵셔널. nil이면 키 자체를 안 보내고
            /// backend/app/schemas/diagnosis.py SpaceInput의 기본값(2.0㎡)이
            /// 적용된다(synthesized Encodable이 nil optional 프로퍼티는
            /// encodeIfPresent로 처리해 키를 생략한다).
            let door_area_m2: Double?
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
            // calc-v2(docs/result-screen-v9-design.md) — ⚠️ 이 세 값은 원문
            // 미대조 잠정 추정치("-unverified" 접미사로 표시됨).
            let current_u_value_ceiling: String
            let current_u_value_floor: String
            let current_u_value_door: String
        }
        struct Baseline: Codable {
            let window_heat_loss_kwh: Double
            let wall_heat_loss_kwh: Double
            // calc-v2 신규 — total_heat_loss_kwh는 이제 이 5개 부위 합계다.
            let ceiling_heat_loss_kwh: Double
            let floor_heat_loss_kwh: Double
            let door_heat_loss_kwh: Double
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
        /// calc-v2 — PRD v8.3: 반드시 disclaimer(참고용 추정치 고지)를 등급
        /// 바로 옆에 같이 표시해야 한다.
        struct EfficiencyLevel: Codable {
            let band_level: Int
            let label: String
            let kwh_per_m2: Double
            let disclaimer: String
        }

        let calculation_version: String
        let reference_data_version: ReferenceDataVersion
        let baseline: Baseline
        let scenarios: [Scenario]
        let wall_anomaly_notice: WallAnomalyNotice
        let unit_scope_disclaimer: String
        let efficiency_level: EfficiencyLevel
        let ai_summary: String
        /// wall.visible_anomaly_confirmed == "suspected"일 때만 "높음", 그 외엔 nil.
        let leak_priority: String?
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
