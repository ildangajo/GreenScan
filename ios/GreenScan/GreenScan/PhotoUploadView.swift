import SwiftUI
import PhotosUI

/// 웹 frontend/src/features/vision-analysis/PhotoUploadPage.tsx의 포팅
/// (화면 3: 사진 업로드 + AI 후보 확인 — POST /api/v1/photos/analyze가
/// 사진 1장당 즉시 후보를 돌려주는 동기 API라 두 화면으로 나눌 이유가
/// 없어서 웹에서도 합쳤던 화면).
///
/// api-spec.md 5.0절: 흐린 사진은 서버 호출 전 클라이언트(BlurDetection)에서
/// 먼저 걸러 재촬영을 안내한다(서버 판정을 대체하지 않음). 블러로 판정돼도
/// "그래도 분석하기"로 강제 진행할 수 있다.
///
/// 사진 없이도 다음 단계로 진행할 수 있다(PRD) — 그 경우 아래 확정 칩들을
/// 직접 골라서 DiagnosisFlowState에 채우면 된다.
struct PhotoUploadView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var windowSlot: SlotState = .empty
    @State private var wallSlot: SlotState = .empty
    @State private var navigateToResult = false

    private static let windowTypeOptions = [
        ("single", "단창"), ("double", "복층창"), ("triple", "삼중창"),
    ]
    private static let lowEOptions = [
        ("yes", "적용"), ("no", "미적용"), ("unknown", "모름"),
    ]
    private static let anomalyOptions = [
        ("suspected", "있음 (현장 점검 권장)"), ("none_observed", "없음"),
    ]

    enum SlotState {
        case empty
        case checkingBlur(fileName: String)
        case blurry(fileName: String, jpegData: Data)
        case analyzing(fileName: String)
        case done(fileName: String, result: PhotosAPI.PhotoAnalysisResponse)
        case error(fileName: String, message: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhotoSlotView(
                        label: "창호 사진",
                        category: .window,
                        slot: windowSlot,
                        onPick: { data, name in handlePick(category: .window, jpegData: data, fileName: name) },
                        onForceContinue: { forceContinueWindow() }
                    )
                    if case .done = windowSlot {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGroup(label: "창호 유형 확정", options: Self.windowTypeOptions, selected: flow.windowTypeConfirmed) {
                                flow.windowTypeConfirmed = $0
                            }
                            chipGroup(label: "Low-E 여부 (AI가 판별하지 않는 값 — 육안/시공 기록으로 확인)", options: Self.lowEOptions, selected: flow.lowE) {
                                flow.lowE = $0
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "535353").opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    PhotoSlotView(
                        label: "벽체 사진",
                        category: .wall,
                        slot: wallSlot,
                        onPick: { data, name in handlePick(category: .wall, jpegData: data, fileName: name) },
                        onForceContinue: { forceContinueWall() }
                    )
                    if case .done = wallSlot {
                        VStack(alignment: .leading, spacing: 8) {
                            chipGroup(label: "사진상 이상 흔적 여부 확정", options: Self.anomalyOptions, selected: flow.anomalyConfirmed) {
                                flow.anomalyConfirmed = $0
                            }
                            Text("이 값은 결과 화면의 현장 점검 안내에만 반영되며, U값·면적·열손실 수치를 바꾸지 않습니다.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "535353").opacity(0.6))
                        }
                        .padding(16)
                        .background(Color(hex: "535353").opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if isEmpty(windowSlot), isEmpty(wallSlot) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("사진을 올리지 않으면 아래 항목을 직접 선택해서 진행할 수 있습니다.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "535353").opacity(0.6))
                            chipGroup(label: "창호 유형", options: Self.windowTypeOptions, selected: flow.windowTypeConfirmed) {
                                flow.windowTypeConfirmed = $0
                            }
                            chipGroup(label: "Low-E 여부", options: Self.lowEOptions, selected: flow.lowE) {
                                flow.lowE = $0
                            }
                            chipGroup(label: "벽체 이상 흔적 여부", options: Self.anomalyOptions, selected: flow.anomalyConfirmed) {
                                flow.anomalyConfirmed = $0
                            }
                        }
                        .padding(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("촬영 가이드").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                        Text("— 창호는 프레임과 유리면이 함께 보이게 찍어주세요\n— 벽체는 의심 부위가 흐리지 않게 가까이서 찍어주세요\n— 어두움, 강한 반사, 원거리 촬영은 재촬영 대상입니다")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "535353").opacity(0.7))
                    }
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.2), lineWidth: 1))

                    Text("업로드한 사진은 AI 분석을 위해 외부 API로 전송되며, GreenScan 서버에는 원본이 저장되지 않습니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "535353").opacity(0.5))
                }
                .padding(.horizontal, 21)
                .padding(.bottom, 100)
            }

            nextButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToResult) {
            ResultView()
        }
    }

    private func isEmpty(_ slot: SlotState) -> Bool {
        if case .empty = slot { return true }
        return false
    }

    private var header: some View {
        HStack(spacing: 21) {
            Button(action: { dismiss() }) {
                Image("icon-chevron-left").resizable().frame(width: 24, height: 24)
            }
            Text("창호와 벽체 사진을 올려주세요")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "535353"))
            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func chipGroup(label: String, options: [(String, String)], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "535353").opacity(0.8))
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { value, optionLabel in
                    Button {
                        onSelect(value)
                    } label: {
                        Text(optionLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selected == value ? .white : Color(hex: "535353"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected == value ? Color.brand400 : Color(.systemBackground))
                            .overlay(Capsule().strokeBorder(selected == value ? Color.clear : Color(hex: "535353").opacity(0.3), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nextButton: some View {
        Button {
            navigateToResult = true
        } label: {
            Text("다음")
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

    private func handlePick(category: PhotosAPI.PhotoCategory, jpegData: Data, fileName: String) {
        let setSlot: (SlotState) -> Void = category == .window ? { windowSlot = $0 } : { wallSlot = $0 }
        setSlot(.checkingBlur(fileName: fileName))

        guard let image = UIImage(data: jpegData) else {
            Task { await runAnalyze(category: category, jpegData: jpegData, fileName: fileName) }
            return
        }

        // 블러 체크 자체가 실패해도(예: 픽셀을 못 읽음) 서버 분석은 계속 진행한다 —
        // 이건 어디까지나 사전 안내용 보조 체크일 뿐이다.
        if let result = BlurDetection.checkBlur(image: image), result.isBlurry {
            setSlot(.blurry(fileName: fileName, jpegData: jpegData))
            return
        }

        Task { await runAnalyze(category: category, jpegData: jpegData, fileName: fileName) }
    }

    private func forceContinueWindow() {
        guard case .blurry(let fileName, let jpegData) = windowSlot else { return }
        Task { await runAnalyze(category: .window, jpegData: jpegData, fileName: fileName) }
    }

    private func forceContinueWall() {
        guard case .blurry(let fileName, let jpegData) = wallSlot else { return }
        Task { await runAnalyze(category: .wall, jpegData: jpegData, fileName: fileName) }
    }

    @MainActor
    private func runAnalyze(category: PhotosAPI.PhotoCategory, jpegData: Data, fileName: String) async {
        let setSlot: (SlotState) -> Void = category == .window ? { windowSlot = $0 } : { wallSlot = $0 }
        setSlot(.analyzing(fileName: fileName))
        do {
            let result = try await PhotosAPI.analyze(category: category, jpegData: jpegData)
            setSlot(.done(fileName: fileName, result: result))

            if category == .window, ["single", "double", "triple"].contains(result.window_type_candidate) {
                flow.windowTypeConfirmed = result.window_type_candidate
            }
            if category == .wall, ["suspected", "none_observed"].contains(result.visible_anomaly_candidate) {
                flow.anomalyConfirmed = result.visible_anomaly_candidate
            }
        } catch {
            let message = (error as? ApiError)?.message ?? "사진 분석에 실패했습니다."
            setSlot(.error(fileName: fileName, message: message))
        }
    }
}

private struct PhotoSlotView: View {
    let label: String
    let category: PhotosAPI.PhotoCategory
    let slot: PhotoUploadView.SlotState
    let onPick: (Data, String) -> Void
    let onForceContinue: () -> Void

    @State private var pickerItem: PhotosPickerItem?

    private var isBusy: Bool {
        switch slot {
        case .checkingBlur, .analyzing: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack {
                    Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                    Spacer()
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "535353").opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.3), lineWidth: 1))
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.6 : 1)
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    guard
                        let data = try? await newItem.loadTransferable(type: Data.self),
                        let image = UIImage(data: data),
                        let jpegData = image.jpegData(compressionQuality: 0.85)
                    else { return }
                    onPick(jpegData, newItem.itemIdentifier ?? "photo.jpg")
                    pickerItem = nil
                }
            }

            if case .blurry = slot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("사진이 흐려서 인식이 어려울 수 있어요.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "b45309"))
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Text("다시 촬영")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "b45309"))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .overlay(Capsule().strokeBorder(Color(hex: "b45309"), lineWidth: 1))
                        }
                        Button(action: onForceContinue) {
                            Text("그래도 분석하기")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color(hex: "b45309"))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "b45309").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if case .error(_, let message) = slot {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            if case .done(_, let result) = slot {
                Text("\"\(result.reason_summary)\" — 실제 사양 확정치가 아닌 시각적 후보입니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "535353").opacity(0.6))
            }
        }
    }

    private var statusText: String {
        switch slot {
        case .empty:
            return "사진 선택"
        case .checkingBlur:
            return "사진 확인 중..."
        case .analyzing:
            return "분석 중..."
        case .blurry(let fileName, _):
            return fileName
        case .error(let fileName, _):
            return fileName
        case .done(_, let result):
            let candidate = category == .window ? result.window_type_candidate : result.visible_anomaly_candidate
            return candidate == "not_applicable" ? "분석 완료" : "AI 후보: \(candidateLabel(candidate))"
        }
    }

    private func candidateLabel(_ value: String) -> String {
        switch value {
        case "single": return "단창"
        case "double": return "복층창"
        case "triple": return "삼중창"
        case "suspected": return "이상 흔적 있음"
        case "none_observed": return "이상 흔적 없음"
        case "unassessable": return "판별 불가"
        default: return value
        }
    }
}

#Preview {
    PhotoUploadView().environment(DiagnosisFlowState())
}
