import SwiftUI

/// 홈 히어로("AI 진단 시작하기")를 누르면 AiDiagnosisView보다 먼저 뜨는
/// 5단계 사전 설문(PM 지시 2026-09-12, Figma 목업 기준). 설문을 완료해야
/// 기존 진단 플로우(AiDiagnosisView → 건물유형 → 공간입력 → 사진 → 결과)로
/// 넘어간다.
///
/// 백엔드 연동 주의: 이 설문 답변들은 계산 API 계약(CalculateRequest)에
/// 대응하는 필드가 없다 — DiagnosisFlowState.survey* 필드에만 저장하고
/// 지금은 어디로도 전송하지 않는다(docs/lidar-space-capture-proposal.md와
/// 같은 이유로, 수집 목적이 정해지면 그때 API를 따로 정의해야 한다).
struct SurveyView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var navigateToAiDiagnosis = false
    private let totalSteps = 5

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
        case 1: buildingCategoryStep
        case 2: discomfortStep
        case 3: conditionStep
        case 4: preferredRemodelStep
        default: completeStep
        }
    }

    // MARK: - 1/5 건물 종류

    private var buildingCategoryStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("건물의 종류는\n어떤가요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("가장 적합한 항목을 선택해주세요")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            optionCard(icon: "house.fill", label: "단독주택", selected: flow.surveyBuildingCategory == "detached") {
                flow.surveyBuildingCategory = "detached"
            }
            optionCard(icon: "building.2.fill", label: "공동주택 (아파트, 빌라 등)", selected: flow.surveyBuildingCategory == "multi") {
                flow.surveyBuildingCategory = "multi"
            }
            optionCard(icon: "ellipsis.circle.fill", label: "기타", selected: flow.surveyBuildingCategory == "other") {
                flow.surveyBuildingCategory = "other"
            }
        }
    }

    private func optionCard(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(selected ? Color.brand500 : Color(hex: "BEBEBE").opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundStyle(selected ? .white : Color(hex: "535353"))
                }
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "535353"))
                Spacer()
            }
            .padding(14)
            .background(selected ? Color.brand50 : Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.brand500 : Color(hex: "BEBEBE").opacity(0.3), lineWidth: selected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2/5 불편한 점 (복수 선택)

    private let discomfortOptions: [(key: String, icon: String, label: String, sub: String)] = [
        ("cold", "snowflake", "너무 추워요", "(난방 문제)"),
        ("hot", "sun.max.fill", "너무 더워요", "(냉방 문제)"),
        ("ventilation", "wind", "환기가 잘 안돼요", ""),
        ("expensive", "wonsign.circle.fill", "너무 비싸요", ""),
    ]

    private var discomfortStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("가장 불편한 점은\n무엇인가요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("(복수 선택 가능)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(discomfortOptions, id: \.key) { option in
                    let selected = flow.surveyDiscomforts.contains(option.key)
                    Button {
                        if selected { flow.surveyDiscomforts.remove(option.key) } else { flow.surveyDiscomforts.insert(option.key) }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? .white : Color.brand500)
                                .frame(width: 44, height: 44)
                                .background(selected ? Color.brand500 : Color.brand50)
                                .clipShape(Circle())
                            Text(option.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                            if !option.sub.isEmpty {
                                Text(option.sub).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(selected ? Color.brand50 : Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.brand500 : Color(hex: "BEBEBE").opacity(0.3), lineWidth: selected ? 1.5 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3/5 현재 상태 체크 (슬라이더)

    private let conditionItems: [(key: String, icon: String, label: String)] = [
        ("insulation", "thermometer.medium", "단열 성능"),
        ("window", "rectangle.split.2x1", "창호 상태"),
        ("hvac", "wind.circle.fill", "냉난방 설비"),
        ("ventilation", "arrow.triangle.2.circlepath", "환기"),
        ("lighting", "lightbulb.fill", "조명 설비"),
    ]

    private var conditionStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("각 항목의 현재 상태를\n체크해주세요.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
                .padding(.bottom, 16)

            VStack(spacing: 20) {
                ForEach(conditionItems, id: \.key) { item in
                    conditionSlider(icon: item.icon, label: item.label, key: item.key)
                }
            }
        }
    }

    private func conditionSlider(icon: String, label: String, key: String) -> some View {
        let binding = Binding<Double>(
            get: { flow.surveyConditionRatings[key] ?? 0.5 },
            set: { flow.surveyConditionRatings[key] = $0 }
        )
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.brand500)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(hex: "535353"))
                Slider(value: binding, in: 0...1)
                    .tint(Color.brand500)
                HStack {
                    Text("나쁨").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Text("보통").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Text("좋음").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 4/5 선호 리모델링 (복수 선택, 이미지 카드)

    private let remodelOptions: [(key: String, label: String, sub: String, colors: [String])] = [
        ("insulation", "단열 강화", "(에너지 효율 개선)", ["e4efe9", "7fae93"]),
        ("window", "창호 교체", "(단열 성능 향상)", ["dbeafe", "60a5fa"]),
        ("exterior", "외관 리모델링", "(건물 이미지 개선)", ["fef3c7", "f59e0b"]),
        ("solar", "태양광 설치", "(신재생 에너지)", ["fee2e2", "f87171"]),
    ]

    private var preferredRemodelStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("어떤 리모델링을\n선호하시나요?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("선호하는 이미지를 선택해주세요 (복수 선택 가능)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(remodelOptions, id: \.key) { option in
                    let selected = flow.surveyPreferredRemodels.contains(option.key)
                    Button {
                        if selected { flow.surveyPreferredRemodels.remove(option.key) } else { flow.surveyPreferredRemodels.insert(option.key) }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            LinearGradient(colors: option.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .frame(height: 90)
                                .overlay(alignment: .topTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white, Color.brand500)
                                            .padding(8)
                                    }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                                Text(option.sub).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            .padding(10)
                        }
                        .background(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.brand500 : Color(hex: "BEBEBE").opacity(0.3), lineWidth: selected ? 1.5 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5/5 완료

    private var completeStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.brand50).frame(width: 72, height: 72)
                Image(systemName: "house.fill").font(.system(size: 30)).foregroundStyle(Color.brand500)
            }
            .padding(.top, 40)
            Text("설문이 완료되었어요!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "535353"))
            Text("지금부터 상세정보를 입력 후\n맞춤형 리모델링 솔루션을 준비할게요.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Image(systemName: "building.2.fill")
                .font(.system(size: 90))
                .foregroundStyle(Color.brand300)
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
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
                .background(Color.brand500)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }

    // 1단계(건물 종류)만 필수 단일선택 — 나머지는 선택 안 해도 다음으로 진행 가능
    // (복수선택 항목을 "0개도 허용"으로 둔 건 Figma 목업에 필수 표시가 없어서다).
    private var canProceed: Bool {
        switch step {
        case 1: return !flow.surveyBuildingCategory.isEmpty
        default: return true
        }
    }
}

#Preview {
    NavigationStack {
        SurveyView().environment(DiagnosisFlowState())
    }
}
