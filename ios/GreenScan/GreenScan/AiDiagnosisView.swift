import SwiftUI

/// frontend/src/features/ai-diagnosis/AiDiagnosisStartPage.tsx의 포팅.
/// Figma node 18:141 실측값(색상/치수) 그대로 옮겼다. 아직 API 클라이언트가
/// 없어서 "확인"/"분석 시작하기"는 실제 네트워크 호출 없이 로컬 상태만
/// 바꾸는 데모 동작이다 — 진단 플로우(공간치수~결과)는 보류 지시로 아직
/// 연결 안 함.
struct AiDiagnosisView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photoCount = 0
    @State private var address = ""
    @State private var addressStatus: AddressStatus = .idle
    @State private var selectedYear: String? = nil

    private let yearOptions = ["2016년 7월 ~ 2023년 2월", "2023년 2월 이후"]

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
                ForEach(yearOptions, id: \.self) { year in
                    Button(year) { selectedYear = year }
                }
            } label: {
                HStack {
                    Text(selectedYear ?? "선택해주세요")
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
            .padding(3)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
        .padding(.top, 24)
    }

    private var startButton: some View {
        Button {
            // TODO: 진단 플로우 연결 보류 중 — 나중에 /start(건물유형 선택)로 이어붙인다.
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
        addressStatus = .checking
        // TODO: 실제 /api/v1/map/geocode 연동 전까지 데모용 규칙(PRD: 서울만 지원)만 흉내낸다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if address.contains("서울") {
                addressStatus = .ok(region: "seoul")
            } else {
                addressStatus = .error("지원하지 않는 지역입니다.")
            }
        }
    }
}

#Preview {
    AiDiagnosisView()
}
