import SwiftUI

/// 홈 히어로("AI 진단 시작하기")를 누르면 AiDiagnosisView보다 먼저 뜨는
/// 사전 설문. v1(2026-09-12, Figma 목업 기준)은 답변을 confirmed_input
/// 스냅샷에만 저장했는데, v2(같은 날, PM 지시로 실측 연계형 개편)부터는
/// 답 대부분이 실제 계산 필드(building_type/representative_space_type/
/// 공간 치수/창호면적/벽체면적/construction_year_range/
/// wall.visible_anomaly_confirmed/window_type)를 직접 채운다.
///
/// "설문 = 사전 필터" 원칙(PM 확정, 2026-09-12): 여기서 채운 값은 전부
/// DiagnosisFlowState의 실제 필드라서, 뒤에 나오는
/// BuildingSpaceSelectView/AiDiagnosisView/SpaceInputView/PhotoUploadView는
/// 코드 변경 없이도 그 값을 "이미 선택된 상태"로 보여준다(각 화면이 로컬
/// @State 복제 없이 flow를 직접 바인딩하기 때문) — 사용자는 그 화면에서
/// 다시 확인하거나 고칠 수 있다. 예외는 AiDiagnosisView의 주소/연도 필드뿐
/// (로컬 @State라 별도 프리필 처리를 해뒀다, AiDiagnosisView.swift 참고).
///
/// 계산에 영향을 주면 안 된다고 팀이 합의한 "불편한 점"(Q2)만 여전히
/// CalculateRequest.survey에 담겨 confirmed_input 스냅샷 전용으로 저장된다
/// (±15% 같은 임의 보정 금지 — 2026-09-12 팀 리뷰 결론).
struct SurveyView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var navigateToAiDiagnosis = false
    private let totalSteps = 5

    // Q1 — 건물유형/대표공간 + 크기 프리셋
    @State private var selectedSpaceKey: String?
    @State private var selectedSizePreset: SizePreset?

    // Q3 — 집 상태(연식 + 벽 이상 징후)
    @State private var yearOptions: [ReferenceAPI.ConstructionYearRangeOption] = []
    @State private var selectedConditionOption: ConditionOption?

    // Q4 — 창문 반사 테스트
    @State private var selectedWindowTestOption: WindowTestOption?

    // Q5 — 주소(district 수준 — 실제 지오코딩/region_id 확정은 AiDiagnosisView에서)
    @State private var address = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(.horizontal, 21)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
            if step < totalSteps {
                footer
            } else {
                finishButton
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToAiDiagnosis) {
            AiDiagnosisView()
        }
        .task {
            await loadYearOptions()
        }
    }

    private func loadYearOptions() async {
        yearOptions = (try? await ReferenceAPI.constructionYearRanges()) ?? []
    }

    // MARK: - 헤더(진행바 + 뒤로가기 + 단계 표시)

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    if step > 1 { step -= 1 } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "535353"))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "BEBEBE").opacity(0.25))
                        Capsule()
                            .fill(Color.brand500)
                            .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps))
                            .animation(.easeOut(duration: 0.25), value: step)
                    }
                }
                .frame(height: 6)
                Text("\(step)/\(totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 21)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: spaceStep
        case 2: discomfortStep
        case 3: conditionStep
        case 4: windowTestStep
        default: addressStep
        }
    }

    // MARK: - 1/5 어떤 곳을 진단할까요? (건물유형+대표공간 조합 + 크기)

    private struct SpaceOption: Identifiable {
        let key: String
        let label: String
        let buildingType: String
        let spaceType: String
        var id: String { key }
    }

    /// 서버 값(GET /reference/options)과 정확히 일치해야 하는 키 —
    /// detached_multi_household/apartment, living_room/main_bedroom.
    private static let spaceOptions: [SpaceOption] = [
        .init(key: "detached_living", label: "단독·다가구 - 거실", buildingType: "detached_multi_household", spaceType: "living_room"),
        .init(key: "detached_room", label: "단독·다가구 - 방", buildingType: "detached_multi_household", spaceType: "main_bedroom"),
        .init(key: "apartment_living", label: "아파트 - 거실", buildingType: "apartment", spaceType: "living_room"),
        .init(key: "apartment_room", label: "아파트 - 방", buildingType: "apartment", spaceType: "main_bedroom"),
    ]

    /// 공간 치수 실측 전 프리셋 — 라이다/줄자 실측 전까지 계산이 쓸 근사값.
    /// SpaceInputView에서 언제든 다시 고칠 수 있어서(치수 출처 "manual") 값
    /// 자체보다 "합리적인 중간값"인지가 중요하다. 대표 공간(거실/방) 1개
    /// 기준.
    private enum SizePreset: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small: return "좁아요 (10평 이하)"
            case .medium: return "보통 (10~20평)"
            case .large: return "넓어요 (20평 이상)"
            }
        }
        var dims: (width: Double, depth: Double, height: Double, window: Double, wall: Double) {
            switch self {
            case .small: return (3.6, 3.0, 2.4, 1.8, 7.0)
            case .medium: return (4.5, 4.0, 2.4, 3.0, 10.5)
            case .large: return (6.0, 5.0, 2.5, 4.5, 15.0)
            }
        }
    }

    private var spaceStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("어떤 곳을\n진단할까요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("가장 가까운 항목을 선택해주세요")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.spaceOptions) { option in
                    pillCard(label: option.label, selected: selectedSpaceKey == option.key) {
                        selectedSpaceKey = option.key
                        flow.buildingType = option.buildingType
                        flow.spaceType = option.spaceType
                    }
                }
            }

            Text("대략적인 크기는요?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "535353"))
                .padding(.top, 20)

            VStack(spacing: 8) {
                ForEach(SizePreset.allCases) { preset in
                    pillCard(label: preset.label, selected: selectedSizePreset == preset) {
                        applySizePreset(preset)
                    }
                }
            }

            Text("나중에 라이다 스캔이나 직접 입력으로 정확한 치수로 바꿀 수 있어요.")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "535353").opacity(0.5))
                .padding(.top, 4)
        }
    }

    private func applySizePreset(_ preset: SizePreset) {
        selectedSizePreset = preset
        let dims = preset.dims
        flow.width = String(format: "%.1f", dims.width)
        flow.depth = String(format: "%.1f", dims.depth)
        flow.height = String(format: "%.1f", dims.height)
        flow.floorArea = String(format: "%.1f", dims.width * dims.depth)
        flow.windowArea = String(format: "%.1f", dims.window)
        flow.wallArea = String(format: "%.1f", dims.wall)
        flow.spaceInputSource = "manual"
    }

    private func pillCard(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? .white : Color(hex: "535353"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Color.brand500 : Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.clear : Color(hex: "BEBEBE").opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2/5 불편한 점 (복수 선택, "없음"은 단독 선택)

    private let discomfortOptions: [(key: String, icon: String, label: String)] = [
        ("cold", "snowflake", "겨울에 너무 추워요"),
        ("hot", "sun.max.fill", "여름에 너무 더워요"),
        ("heating_cost", "wonsign.circle.fill", "난방비가 많이 나와요"),
        ("condensation_mold", "drop.triangle.fill", "벽/유리에 물기·곰팡이가 생겨요"),
        ("none", "checkmark.circle", "특별히 불편한 건 없어요"),
    ]

    private var discomfortStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("요즘 가장\n불편한 점이 뭐예요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("(복수 선택 가능)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(discomfortOptions, id: \.key) { option in
                    let selected = flow.surveyDiscomforts.contains(option.key)
                    Button {
                        toggleDiscomfort(option.key)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option.icon)
                                .foregroundStyle(selected ? .white : Color.brand500)
                            Text(option.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selected ? .white : Color(hex: "535353"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(selected ? Color.brand500 : Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Color.clear : Color(hex: "BEBEBE").opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// "특별히 불편한 건 없어요"는 다른 항목과 동시 선택이 말이 안 돼서
    /// 서로 배타적으로 처리한다.
    private func toggleDiscomfort(_ key: String) {
        if key == "none" {
            flow.surveyDiscomforts = flow.surveyDiscomforts.contains("none") ? [] : ["none"]
        } else if flow.surveyDiscomforts.contains(key) {
            flow.surveyDiscomforts.remove(key)
        } else {
            flow.surveyDiscomforts.remove("none")
            flow.surveyDiscomforts.insert(key)
        }
    }

    // MARK: - 3/5 이 집 상태는 어때요? (연식 + 벽 이상 징후 압축)

    private enum ConditionOption: CaseIterable {
        case oldWithAnomaly, oldClean, recent, unknown

        var label: String {
            switch self {
            case .oldWithAnomaly: return "지은 지 오래됐고 벽에 얼룩/갈라짐이 보여요"
            case .oldClean: return "지은 지 오래됐지만 벽은 깨끗해요"
            case .recent: return "비교적 최근에 지어졌어요"
            case .unknown: return "잘 모르겠어요"
            }
        }
    }

    private var conditionStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이 집 상태는\n어때요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("연식과 벽 상태를 대략 알려주시면 계산 기준을 더 정확히 잡을 수 있어요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(ConditionOption.allCases, id: \.label) { option in
                    optionRow(label: option.label, selected: selectedConditionOption == option) {
                        applyConditionOption(option)
                    }
                }
            }

            if selectedConditionOption == .unknown {
                Text("괜찮아요 — 다음 화면(건물 연도)에서 직접 골라주시면 돼요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "535353").opacity(0.6))
                    .padding(.top, 4)
            }
        }
    }

    /// construction_year_range는 서버가 내려주는 실제 연식 구간 중 "가장
    /// 오래된"/"가장 최근" 구간으로 근사한다(min_year 기준 — 배열 순서에
    /// 기대지 않는다). 벽 이상 징후는 wall.visible_anomaly_confirmed로 그대로
    /// 매핑 — "잘 모르겠어요"는 아무것도 정하지 않고 뒤 화면에서 직접
    /// 고르게 둔다.
    private func applyConditionOption(_ option: ConditionOption) {
        selectedConditionOption = option
        switch option {
        case .oldWithAnomaly:
            if let oldest = yearOptions.min(by: { $0.value < $1.value }) ?? yearOptions.first {
                flow.constructionYearRange = oldest.value
            }
            flow.anomalyConfirmed = "suspected"
        case .oldClean:
            if let oldest = yearOptions.min(by: { $0.value < $1.value }) ?? yearOptions.first {
                flow.constructionYearRange = oldest.value
            }
            flow.anomalyConfirmed = "none_observed"
        case .recent:
            if let newest = yearOptions.max(by: { $0.value < $1.value }) ?? yearOptions.last {
                flow.constructionYearRange = newest.value
            }
            flow.anomalyConfirmed = "none_observed"
        case .unknown:
            break
        }
    }

    // MARK: - 4/5 창문에 손전등을 대보면, 불빛이 몇 개로 보이나요? (반사 테스트)

    private enum WindowTestOption: CaseIterable {
        case two, four, unknown

        var label: String {
            switch self {
            case .two: return "2개 보여요"
            case .four: return "4개 보여요"
            case .unknown: return "잘 모르겠어요"
            }
        }
    }

    private var windowTestStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("창문에 손전등을 대보면,\n불빛이 몇 개로 보이나요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("밤에 창문 안쪽에서 손전등(핸드폰 플래시)을 비추면 유리에 반사된 불빛 개수로 단창/복층창을 구분할 수 있어요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(WindowTestOption.allCases, id: \.label) { option in
                    optionRow(label: option.label, selected: selectedWindowTestOption == option) {
                        selectedWindowTestOption = option
                        switch option {
                        case .two: flow.windowTypeConfirmed = "single"
                        case .four: flow.windowTypeConfirmed = "double"
                        case .unknown: break
                        }
                    }
                }
            }

            if selectedWindowTestOption == .unknown {
                Text("괜찮아요 — 사진 확인 화면에서 직접 골라주시면 돼요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "535353").opacity(0.6))
                    .padding(.top, 4)
            }
        }
    }

    private func optionRow(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.brand500 : Color(hex: "535353").opacity(0.3))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "535353"))
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(selected ? Color.brand50 : Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Color.brand500 : Color(hex: "BEBEBE").opacity(0.3), lineWidth: selected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5/5 어디 사세요? (지역 — 실제 지오코딩/region_id 확정은 AiDiagnosisView)

    /// 여기서는 주소 텍스트만 받아 flow.address에 둔다 — location.region_id
    /// 확정(HDD 계산 필수값)엔 인증된 지오코딩 호출이 필요해서
    /// (AiDiagnosisView, GET /api/v1/map/geocode) 실제 확인은 다음 화면에서
    /// 한다. AiDiagnosisView가 이 값을 프리필해서 사용자가 다시 타이핑할
    /// 필요 없이 "확인"만 누르면 되게 해뒀다.
    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("어디 사세요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("시/군/구까지만 알려주셔도 돼요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            TextField("예) 서울시 마포구", text: $address)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "535353"))
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(Color(hex: "BEBEBE").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onChange(of: address) { flow.address = address }

            Text("다음 화면에서 정확한 주소로 다시 확인해요(HDD 계산에 필요).")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "535353").opacity(0.5))
                .padding(.top, 4)
        }
    }

    // MARK: - 하단 이전/다음

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                if step > 1 { step -= 1 } else { dismiss() }
            } label: {
                Text("이전")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "535353"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(hex: "BEBEBE").opacity(0.15))
                    .clipShape(Capsule())
            }
            Button {
                step += 1
            } label: {
                Text("다음")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canProceed ? Color.brand500 : Color(hex: "535353").opacity(0.3))
                    .clipShape(Capsule())
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }

    private var finishButton: some View {
        Button {
            navigateToAiDiagnosis = true
        } label: {
            Text("AI 분석하기")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(canProceed ? Color.brand500 : Color(hex: "535353").opacity(0.3))
                .clipShape(Capsule())
        }
        .disabled(!canProceed)
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }

    // 1(공간+크기)/3(집 상태)/4(창문 테스트)/5(주소)는 필수 단일선택(또는
    // 텍스트), 2(불편한 점)만 0개 선택도 허용한다.
    private var canProceed: Bool {
        switch step {
        case 1: return selectedSpaceKey != nil && selectedSizePreset != nil
        case 3: return selectedConditionOption != nil
        case 4: return selectedWindowTestOption != nil
        case 5: return !address.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }
}

#Preview {
    NavigationStack {
        SurveyView().environment(DiagnosisFlowState())
    }
}
