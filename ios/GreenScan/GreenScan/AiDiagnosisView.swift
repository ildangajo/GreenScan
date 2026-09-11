import SwiftUI

/// frontend/src/features/ai-diagnosis/AiDiagnosisStartPage.tsx의 포팅.
/// Figma node 18:141 실측값(색상/치수) 그대로 옮겼다. 주소 확인은
/// GET /api/v1/map/geocode 실연동(2026-09-12) — 이 엔드포인트는 로그인이
/// 필요해서(api-spec.md 1.1) 세션 토큰이 없으면(비로그인 또는 오프라인 데모
/// 계정) 호출하지 않고 안내만 보여준다. "분석 시작하기"를 누르면 주소/연도를
/// DiagnosisFlowState에 저장하고 BuildingSpaceSelectView(건물유형/대표공간)로
/// 이어간다.
struct AiDiagnosisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var auth
    @Environment(DiagnosisFlowState.self) private var flow

    @State private var photoCount = 0
    @State private var address = ""
    @State private var addressStatus: AddressStatus = .idle
    /// construction_year_range 값(예: "2018_present") — 계산 API가 그대로 받는 키.
    @State private var selectedYear: String? = nil
    @State private var yearOptions: [ReferenceAPI.ConstructionYearRangeOption] = []
    @State private var yearOptionsLoadFailed = false
    @State private var navigateToSpaceFlow = false

    enum AddressStatus: Equatable {
        case idle, checking, ok(region: String), error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoCard
                    headline
                    addressField
                    yearField
                    Text("건물유형·대표공간·공간 치수·창호·벽체 정보는 다음 화면들에서 이어서 입력합니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "535353").opacity(0.7))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "535353").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        .padding(.top, 24)
                }
                .padding(.horizontal, 21)
                .padding(.bottom, 100)
            }

            startButton
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToSpaceFlow) {
            BuildingSpaceSelectView()
        }
        .task {
            await loadYearOptions()
        }
    }

    private func loadYearOptions() async {
        do {
            yearOptions = try await ReferenceAPI.constructionYearRanges()
            yearOptionsLoadFailed = false
        } catch {
            yearOptionsLoadFailed = true
        }
    }

    private var header: some View {
        HStack(spacing: 21) {
            Button(action: { dismiss() }) {
                Image("icon-chevron-left").resizable().frame(width: 24, height: 24)
            }
            Text("AI 분석하기")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "535353"))
            Spacer()
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var photoCard: some View {
        Button {
            photoCount = 1 // 데모: 실제 포토피커는 진단 플로우와 함께 연결 예정
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: "2fcbaa")).frame(width: 53, height: 53)
                    Image("icon-layers").resizable().frame(width: 24, height: 24)
                }
                Text("사진").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                Text(photoCount > 0 ? "\(photoCount)장 선택됨" : "창호,천장,벽 등을 업로드 해주세요")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "535353"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 27)
            .padding(.horizontal, 38)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    private var headline: some View {
        HStack(alignment: .top, spacing: 16) {
            (
                Text("건물 정보를 입력하면").fontWeight(.heavy)
                + Text("\nAI 맞춤 서비스가 시작됩니다.")
            )
            .font(.system(size: 20))
            .foregroundStyle(Color(hex: "535353"))

            VStack(spacing: 6) {
                Circle().fill(Color(hex: "176b52").opacity(0.5)).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "176b52").opacity(0.8)).frame(width: 10, height: 10)
            }
            .padding(.top, 8)
        }
        .padding(.top, 32)
    }

    private var addressField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("건물 주소 입력").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))

            HStack(spacing: 8) {
                TextField("예) 서울시 마포구 월드컵로 12", text: $address)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "535353"))
                    .padding(.horizontal, 9)
                    .frame(height: 45)
                    .background(Color(hex: "BEBEBE").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onChange(of: address) { addressStatus = .idle }

                Button(action: checkAddress) {
                    Text(addressStatus == .checking ? "확인 중" : "확인")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "2fcbaa"))
                        .clipShape(Capsule())
                }
                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || addressStatus == .checking)
                .opacity(address.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(3)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            switch addressStatus {
            case .ok(let region):
                Text("지원 지역 확인됨 (\(region))").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "176b52"))
            case .error(let message):
                Text(message).font(.system(size: 12, weight: .medium)).foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .padding(.top, 32)
    }

    private var yearField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("건물 연도").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "535353"))

            Menu {
                ForEach(yearOptions, id: \.value) { option in
                    Button(option.label) { selectedYear = option.value }
                }
            } label: {
                HStack {
                    Text(selectedYearLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selectedYear == nil ? Color(hex: "535353").opacity(0.5) : Color(hex: "535353"))
                    Spacer()
                    Image("icon-chevron-down").resizable().frame(width: 14, height: 8)
                }
                .padding(.horizontal, 9)
                .frame(height: 45)
                .background(Color(hex: "BEBEBE").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .disabled(yearOptions.isEmpty)
            .padding(3)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            if yearOptionsLoadFailed {
                Text("건물 연도 목록을 불러오지 못했어요.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 24)
    }

    private var selectedYearLabel: String {
        guard let selectedYear else {
            return yearOptions.isEmpty && !yearOptionsLoadFailed ? "불러오는 중..." : "선택해주세요"
        }
        return yearOptions.first { $0.value == selectedYear }?.label ?? selectedYear
    }

    private var startButton: some View {
        Button {
            guard case .ok(let region) = addressStatus, let selectedYear else { return }
            flow.address = address.trimmingCharacters(in: .whitespaces)
            flow.regionId = region
            flow.constructionYearRange = selectedYear
            navigateToSpaceFlow = true
        } label: {
            Text("분석 시작하기")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 62)
                .padding(.vertical, 13)
                .background(Color(hex: "2fcbaa"))
                .clipShape(Capsule())
        }
        .disabled(!(addressStatus != .idle && isOk(addressStatus)) || selectedYear == nil)
        .opacity((isOk(addressStatus) && selectedYear != nil) ? 1 : 0.4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private func isOk(_ status: AddressStatus) -> Bool {
        if case .ok = status { return true }
        return false
    }

    private func checkAddress() {
        guard let token = auth.sessionToken else {
            addressStatus = .error(
                auth.isLoggedIn
                    ? "오프라인 데모 계정은 주소 확인을 이용할 수 없어요. 실제 계정으로 로그인해주세요."
                    : "로그인 후 이용할 수 있어요."
            )
            return
        }

        addressStatus = .checking
        Task {
            do {
                let result = try await MapAPI.geocode(address: address.trimmingCharacters(in: .whitespaces), token: token)
                addressStatus = .ok(region: result.region_id)
            } catch {
                let message = (error as? ApiError)?.message ?? "주소 확인에 실패했습니다."
                addressStatus = .error(message)
            }
        }
    }
}

#Preview {
    AiDiagnosisView().environment(AuthState()).environment(DiagnosisFlowState())
}
