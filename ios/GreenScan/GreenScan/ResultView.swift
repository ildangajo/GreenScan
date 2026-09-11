import SwiftUI

/// 웹 frontend/src/features/calculation-result/ResultPage.tsx의 포팅
/// (화면 5: 결과 화면, PRD v7 7.5 + v8.2 9.1절 표시 순서/등급 반영).
///
/// 화면 진입 시 DiagnosisFlowState에 쌓인 입력을 CalculateRequest로 조립해
/// POST /api/v1/diagnoses/calculate를 호출한다. 백엔드 응답에 없는 항목
/// ("에너지 효율 레벨", "예상 개선 비용")은 애초에 없다 — 대신 백엔드가 실제로
/// 주는 unit_scope_disclaimer/wall_anomaly_notice를 그대로 쓴다.
struct ResultView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(DiagnosisNavigationPath.self) private var diagnosisNavigationPath
    @Environment(AuthState.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var result: LoadState = .loading
    @State private var saveState: SaveState = .idle

    private static let urgencyLabel = ["긴급", "주의", "권장"]
    private static let urgencyBadgeColor: [Color] = [.red, .orange, .gray]
    private static let urgencyChipColor: [Color] = [.red, .orange, .secondary]

    private static func urgencyIndex(priority: Int) -> Int {
        min(max(priority - 1, 0), urgencyLabel.count - 1)
    }

    /// PRD v8.2 9.1: "총량 수준" 등급은 서버가 내려주는 별도 필드가 아니라
    /// (산정 임계값 정책 미확정, db-spec.md 8장) 프론트가 기존 scenarios의
    /// 우선순위(감소량 큰 순)만 보고 판단한다 — 가장 시급한 개선 시나리오의
    /// 등급을 총량 수준 등급으로 그대로 쓴다. 임의의 % 임계값을 새로 만들지 않는다.
    private static func overallUrgencyIndex(_ scenarios: [CalculateAPI.CalculateResponse.Scenario]) -> Int {
        let topPriority = scenarios.map(\.priority).min() ?? urgencyLabel.count
        return urgencyIndex(priority: topPriority)
    }

    enum LoadState {
        case loading
        case ok(CalculateAPI.CalculateResponse)
        case error(code: String?, message: String)
    }

    enum SaveState: Equatable {
        case idle, saving, saved, failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                content
                    .padding(.horizontal, 21)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
            }

            endButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await runCalculate()
        }
    }

    private var header: some View {
        HStack(spacing: 21) {
            Button(action: { dismiss() }) {
                Image("icon-chevron-left").resizable().frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("GreenScan 추정 연간 열손실 분석")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "535353"))
                Text("\(flow.buildingType == "apartment" ? "아파트" : "단독·다가구주택") · 이 방 기준 · 비공식 추정치")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "535353").opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .loading:
            VStack(spacing: 8) {
                ProgressView()
                Text("계산 중입니다...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)

        case .error(let code, let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(code.map { "계산 실패 (\($0))" } ?? "계산 실패")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.8))
                Button {
                    dismiss()
                } label: {
                    Text("입력값 다시 확인하기")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(.red.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .ok(let data):
            VStack(alignment: .leading, spacing: 20) {
                urgencyCard(data)
                baselineCard(data)
                priorityList(data)

                Text(data.wall_anomaly_notice.message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "535353").opacity(0.8))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.2), lineWidth: 1))

                Text(data.unit_scope_disclaimer)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "535353").opacity(0.6))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "535353").opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4])))

                Text("계산 버전 \(data.calculation_version) · 기준 U값(창호 \(data.reference_data_version.current_u_value_window) → 목표 \(data.reference_data_version.target_u_value)) · HDD \(data.reference_data_version.hdd)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "535353").opacity(0.4))

                saveSection(data)
            }
        }
    }

    /// 저장 시점(계산 즉시 자동 vs 사용자가 명시적으로 누름)은 PRD상 아직
    /// 정책 확정 전이라(db-spec.md 9장, api-spec.md 1.1), 자동 저장하지 않고
    /// 명시적 버튼으로만 저장한다. 로그인하지 않았거나(오프라인 데모 계정
    /// 포함) 세션 토큰이 없으면 저장 자체를 시도하지 않는다.
    @ViewBuilder
    private func saveSection(_ data: CalculateAPI.CalculateResponse) -> some View {
        if auth.sessionToken == nil {
            Text(
                auth.isLoggedIn
                    ? "오프라인 데모 계정은 결과를 저장할 수 없어요. 실제 계정으로 로그인해주세요."
                    : "로그인하면 이 결과를 마이페이지에 저장할 수 있어요."
            )
            .font(.system(size: 12))
            .foregroundStyle(Color(hex: "535353").opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        } else {
            switch saveState {
            case .idle, .saving:
                Button {
                    Task { await saveDiagnosis(data) }
                } label: {
                    HStack(spacing: 6) {
                        if saveState == .saving {
                            ProgressView().tint(Color(hex: "176b52"))
                        }
                        Text(saveState == .saving ? "저장 중..." : "이 결과 저장하기")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "176b52"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "176b52"), lineWidth: 1.5))
                }
                .disabled(saveState == .saving)
            case .saved:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("마이페이지에 저장됐어요.")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "176b52"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message).font(.system(size: 12)).foregroundStyle(.red)
                    Button {
                        Task { await saveDiagnosis(data) }
                    } label: {
                        Text("다시 시도").font(.system(size: 13, weight: .semibold)).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func urgencyCard(_ data: CalculateAPI.CalculateResponse) -> some View {
        let uIdx = Self.overallUrgencyIndex(data.scenarios)
        return VStack(spacing: 6) {
            Text("이 집의 열손실 총량 수준")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "535353").opacity(0.7))
            Text(Self.urgencyLabel[uIdx])
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Self.urgencyBadgeColor[uIdx])
                .clipShape(Capsule())
            Text("참고용 추정치이며 실제와 다를 수 있습니다.")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "535353").opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.15), lineWidth: 1))
    }

    private func baselineCard(_ data: CalculateAPI.CalculateResponse) -> some View {
        let total = data.baseline.total_heat_loss_kwh
        let windowShare = total > 0 ? data.baseline.window_heat_loss_kwh / total : 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("예상 연간 에너지 사용량 (대표 공간 기준 추정)")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "535353").opacity(0.7))
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatNumber(total)).font(.system(size: 24, weight: .bold)).foregroundStyle(Color(hex: "535353"))
                Text("kWh/year").font(.system(size: 12)).foregroundStyle(Color(hex: "535353").opacity(0.6))
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color(hex: "535353").frame(width: geo.size.width * windowShare)
                    Color(hex: "535353").opacity(0.25)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            HStack {
                Text("창호 \(formatNumber(data.baseline.window_heat_loss_kwh)) kWh")
                Spacer()
                Text("벽체 \(formatNumber(data.baseline.wall_heat_loss_kwh)) kWh")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color(hex: "535353").opacity(0.6))
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.15), lineWidth: 1))
    }

    private func priorityList(_ data: CalculateAPI.CalculateResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("개선 우선순위").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))

            VStack(spacing: 10) {
                ForEach(data.scenarios) { scenario in
                    let uIdx = Self.urgencyIndex(priority: scenario.priority)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 8) {
                                Text("\(scenario.priority)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color(hex: "535353"))
                                    .clipShape(Circle())
                                Text(scenario.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Text(Self.urgencyLabel[uIdx])
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Self.urgencyChipColor[uIdx])
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Self.urgencyChipColor[uIdx].opacity(0.12))
                                    .clipShape(Capsule())
                                Text("−\(formatPercent(scenario.reduction_rate))%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "535353"))
                            }
                        }

                        GeometryReader { geo in
                            Color(hex: "535353")
                                .frame(width: geo.size.width * min(scenario.reduction_rate, 1))
                        }
                        .frame(height: 6)
                        .background(Color(hex: "535353").opacity(0.1))
                        .clipShape(Capsule())

                        Text(
                            "연간 \(formatNumber(scenario.annual_reduction_kwh)) kWh 감소 추정"
                                + (scenario.changed_components.isEmpty ? "" : " · \(scenario.changed_components.joined(separator: ", ")) 개선")
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "535353").opacity(0.6))
                    }
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.15), lineWidth: 1))
                }
            }
        }
    }

    private var endButton: some View {
        Button {
            flow.reset()
            diagnosisNavigationPath.path = NavigationPath()
        } label: {
            Text("진단 종료")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(hex: "2fcbaa"))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatPercent(_ rate: Double) -> String {
        let percent = (rate * 1000).rounded() / 10
        return percent == percent.rounded() ? "\(Int(percent))" : String(format: "%.1f", percent)
    }

    /// 계산 API의 InputSource enum은 아직 "manual"/"user_corrected"만 받는다
    /// — "lidar"는 PRD상 예약값일 뿐이라 그대로 보내면 400
    /// INVALID_INPUT_SOURCE로 거부당한다(2026-09-12 재확인,
    /// docs/lidar-space-capture-proposal.md). BE가 lidar를 실제로 받아주기
    /// 전까지는 "사람이 아예 손 안 댄 값은 아니다"라는 의미로 가장 가까운
    /// "user_corrected"에 매핑해서 보낸다. BE가 enum을 열어주면 이 매핑을
    /// 지우고 flow.spaceInputSource를 그대로 보내면 된다.
    private func apiInputSource(_ internalSource: String) -> String {
        internalSource == "lidar" ? "user_corrected" : internalSource
    }

    /// runCalculate()와 saveDiagnosis()가 같은 값을 써야 한다 — 저장하는
    /// confirmed_input은 실제로 계산에 쓰인 요청과 정확히 같아야 의미가 있다.
    private func makeCalculateRequest() -> CalculateAPI.CalculateRequest {
        CalculateAPI.CalculateRequest(
            building: .init(
                building_type: flow.buildingType,
                representative_space_type: flow.spaceType,
                construction_year_range: flow.constructionYearRange
            ),
            space: .init(
                width_m: Double(flow.width) ?? 0,
                depth_m: Double(flow.depth) ?? 0,
                height_m: Double(flow.height) ?? 0,
                floor_area_m2: Double(flow.floorArea) ?? 0,
                input_source: apiInputSource(flow.spaceInputSource)
            ),
            window: .init(
                total_area_m2: Double(flow.windowArea) ?? 0,
                window_type: flow.windowTypeConfirmed,
                low_e: flow.lowE,
                input_source: "user_corrected"
            ),
            wall: .init(
                exterior_total_area_m2: Double(flow.wallArea) ?? 0,
                insulation_status: flow.insulationStatus,
                visible_anomaly_confirmed: flow.anomalyConfirmed,
                input_source: "user_corrected"
            ),
            location: .init(region_id: flow.regionId)
        )
    }

    @MainActor
    private func runCalculate() async {
        guard !flow.regionId.isEmpty else {
            result = .error(code: nil, message: "건물 주소가 확인되지 않았어요. 처음(AI 분석하기)으로 돌아가 주소를 확인해주세요.")
            return
        }

        let payload = makeCalculateRequest()
        do {
            let response = try await CalculateAPI.calculate(payload)
            result = .ok(response)
        } catch let error as ApiError {
            result = .error(code: error.code, message: error.message)
        } catch {
            result = .error(code: nil, message: "계산 요청에 실패했습니다.")
        }
    }

    @MainActor
    private func saveDiagnosis(_ data: CalculateAPI.CalculateResponse) async {
        guard let token = auth.sessionToken else { return }
        saveState = .saving
        do {
            _ = try await DiagnosesAPI.create(
                buildingTypeKey: flow.buildingType,
                regionId: flow.regionId,
                confirmedInput: makeCalculateRequest(),
                calculationResult: data,
                token: token
            )
            saveState = .saved
        } catch {
            let message = (error as? ApiError)?.message ?? "저장에 실패했습니다."
            saveState = .failed(message)
        }
    }
}

#Preview {
    ResultView()
        .environment(DiagnosisFlowState())
        .environment(DiagnosisNavigationPath())
        .environment(AuthState())
}
