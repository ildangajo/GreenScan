import SwiftUI

/// 웹 frontend/src/features/space-input/BuildingSpaceSelectPage.tsx의 포팅
/// (화면 1: 건물유형 + 대표공간 선택, PRD v7 2.1 흐름 1단계). 이 화면 자체는
/// Figma 시안이 없어서 앱의 기존 디자인 토큰(brand 색상, 카드 스타일)만으로
/// 새로 짰다.
struct BuildingSpaceSelectView: View {
    @Environment(DiagnosisFlowState.self) private var flow
    @Environment(\.dismiss) private var dismiss

    @State private var buildingTypes: [ReferenceAPI.OptionItem] = []
    @State private var buildingTypesLoadFailed = false
    @State private var navigateToSpaceInput = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("건물 유형").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))

                        if buildingTypesLoadFailed {
                            Text("건물 유형 목록을 불러오지 못했어요.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                        }

                        VStack(spacing: 8) {
                            ForEach(buildingTypes, id: \.value) { option in
                                optionCard(
                                    label: option.label,
                                    note: buildingTypeNote(for: option.value),
                                    selected: flow.buildingType == option.value
                                ) {
                                    flow.buildingType = option.value
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("대표 공간").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                        HStack(spacing: 8) {
                            ForEach(RepresentativeSpaceType.options, id: \.value) { option in
                                chip(label: option.label, selected: flow.spaceType == option.value) {
                                    flow.spaceType = option.value
                                }
                            }
                        }
                    }

                    Text("상가, 공용부·복도·계단실, 세대 전체 진단은 지원하지 않습니다. 로그인/계정 없이 진행됩니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "535353").opacity(0.7))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .padding(.horizontal, 21)
                .padding(.bottom, 100)
            }

            nextButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToSpaceInput) {
            SpaceInputView()
        }
        .task {
            await loadBuildingTypes()
        }
    }

    private func loadBuildingTypes() async {
        do {
            buildingTypes = try await ReferenceAPI.buildingTypes()
            buildingTypesLoadFailed = false
            if flow.buildingType.isEmpty, let first = buildingTypes.first {
                flow.buildingType = first.value
            }
        } catch {
            buildingTypesLoadFailed = true
        }
    }

    /// 서버는 U값 참조 그룹 키(예: apartment_group)만 내려준다 — 사람이 읽을
    /// 부연설명은 화면 전용이라 여기서만 붙인다.
    private func buildingTypeNote(for value: String) -> String {
        value == "apartment"
            ? "개선 목표 U값: 공동주택 기준 · 세대 내 대표 공간 1개만 지원"
            : "개선 목표 U값: 공동주택 외 기준"
    }

    private var header: some View {
        HStack(spacing: 21) {
            Button(action: { dismiss() }) {
                Image("icon-chevron-left").resizable().frame(width: 24, height: 24)
            }
            Text("건물 유형을 선택하세요")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "535353"))
            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func optionCard(label: String, note: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                Text(note).font(.system(size: 12)).foregroundStyle(Color(hex: "535353").opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(selected ? Color.brand50 : Color(.systemBackground))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.brand400 : Color(hex: "535353").opacity(0.2), lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
            navigateToSpaceInput = true
        } label: {
            Text("다음")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(hex: "2fcbaa"))
                .clipShape(Capsule())
        }
        .disabled(flow.buildingType.isEmpty)
        .opacity(flow.buildingType.isEmpty ? 0.4 : 1)
        .padding(.horizontal, 21)
        .padding(.vertical, 16)
    }
}

#Preview {
    BuildingSpaceSelectView().environment(DiagnosisFlowState())
}
