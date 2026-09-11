import SwiftUI

/// 웹 frontend/src/features/space-input/SpaceInputPage.tsx의 포팅
/// (화면 2: 공간 치수/면적 입력, PRD v7 5.2 필수 입력). insulation_status는
/// backend/app/schemas/diagnosis.py WallInput이 요구하는 필드라 여기서 같이
/// 받는다 — reference/options의 wall_insulation_status_options를 그대로 쓴다.
struct SpaceInputView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var insulationOptions: [ReferenceAPI.OptionItem] = []
    @State private var insulationOptionsLoadFailed = false
    @State private var showRoomScan = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    roomScanEntry

                    VStack(alignment: .leading, spacing: 8) {
                        Text("공간 치수").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                        HStack(spacing: 8) {
                            numericField("가로 (m)", text: bindingFor(\.width), placeholder: "예: 4.2")
                            numericField("세로 (m)", text: bindingFor(\.depth), placeholder: "예: 3.5")
                            numericField("높이 (m)", text: bindingFor(\.height), placeholder: "예: 2.4")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        numericField("바닥면적 (m²) — 참고용, 계산에는 사용되지 않음", text: bindingFor(\.floorArea), placeholder: "예: 14.7")
                        Text("바닥면적은 가로×세로 입력값과의 교차 확인용으로만 쓰입니다.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "535353").opacity(0.6))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("창호").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                        numericField("창호 합산면적 (m²)", text: bindingFor(\.windowArea), placeholder: "예: 3.6")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("벽체").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                        numericField("외기 접촉 벽체 합산면적 (m²)", text: bindingFor(\.wallArea), placeholder: "예: 12.0")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("벽체 단열 상태").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "535353").opacity(0.8))

                            if insulationOptionsLoadFailed {
                                Text("단열 상태 목록을 불러오지 못했어요.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.red)
                            }

                            HStack(spacing: 8) {
                                ForEach(insulationOptions, id: \.value) { option in
                                    chip(label: option.label, selected: flow.insulationStatus == option.value) {
                                        flow.insulationStatus = option.value
                                    }
                                }
                            }
                        }

                        if wallNetAreaInvalid {
                            Text("외기 접촉 벽체 순면적(벽체 합산면적 − 창호 합산면적)이 0 이하예요. 값을 다시 확인해주세요.")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("외기 접촉 벽체 순면적 = 벽체 합산면적 − 창호 합산면적. 0 이하이면 다음 단계로 진행할 수 없습니다.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "535353").opacity(0.6))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                    }
                }
                .padding(.horizontal, 21)
                .padding(.bottom, 100)
            }

            nextButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await loadInsulationOptions()
        }
        .fullScreenCover(isPresented: $showRoomScan) {
            RoomScanView().environment(flow)
        }
    }

    // docs/lidar-space-capture-proposal.md(2026-09-12): 라이다로 스캔하면
    // 아래 필드들이 자동으로 채워진다 — 그래도 사용자가 직접 고칠 수 있게
    // 수동 입력 UI는 그대로 두고, 이 버튼은 값을 "미리 채워주는" 역할만 한다.
    private var roomScanEntry: some View {
        Button {
            showRoomScan = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arkit")
                Text("라이다로 측정하기")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.brand600)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.brand50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func loadInsulationOptions() async {
        do {
            insulationOptions = try await ReferenceAPI.wallInsulationStatusOptions()
            insulationOptionsLoadFailed = false
            if flow.insulationStatus.isEmpty, let first = insulationOptions.first {
                flow.insulationStatus = first.value
            }
        } catch {
            insulationOptionsLoadFailed = true
        }
    }

    // api-spec.md 2.4 / WallNetAreaInvalidError: 벽체 합산면적 - 창호 합산면적이
    // 0 이하면 계산 API가 422로 거부한다. 백엔드까지 왕복하지 않고 여기서 먼저 막는다.
    private var wallNetAreaInvalid: Bool {
        guard let wall = Double(flow.wallArea), let window = Double(flow.windowArea) else { return false }
        return wall - window <= 0
    }

    private var canProceed: Bool {
        !flow.width.isEmpty && !flow.depth.isEmpty && !flow.height.isEmpty
            && !flow.windowArea.isEmpty && !flow.wallArea.isEmpty
            && !flow.insulationStatus.isEmpty && !wallNetAreaInvalid
    }

    private func bindingFor(_ keyPath: ReferenceWritableKeyPath<DiagnosisFlowState, String>) -> Binding<String> {
        Binding(get: { flow[keyPath: keyPath] }, set: { flow[keyPath: keyPath] = $0 })
    }

    private var header: some View {
        HStack(spacing: 21) {
            Button(action: { dismiss() }) {
                Image("icon-chevron-left").resizable().frame(width: 24, height: 24)
            }
            Text("대표 공간 치수를 입력하세요")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "535353"))
            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func numericField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "535353").opacity(0.8))
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "535353"))
                .padding(.horizontal, 9)
                .frame(height: 45)
                .background(Color(hex: "BEBEBE").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : Color(hex: "535353"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.brand400 : Color(.systemBackground))
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Color(hex: "535353").opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var nextButton: some View {
        Button {
            // TODO: 사진 업로드 + AI 후보 확인 화면(다음 항목)으로 이어붙인다.
        } label: {
            Text("다음")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(hex: "2fcbaa"))
                .clipShape(Capsule())
        }
        .disabled(!canProceed)
        .opacity(canProceed ? 1 : 0.4)
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }
}

#Preview {
    SpaceInputView().environment(DiagnosisFlowState())
}
