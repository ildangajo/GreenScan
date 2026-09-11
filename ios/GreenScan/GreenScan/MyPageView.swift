import SwiftUI

/// frontend/src/features/mypage/MyPage.tsx 포팅 — 로그인 안 돼있으면
/// LoginView를 그대로 보여준다(웹의 "세션 없으면 /login으로 리다이렉트"와 같은 효과).
///
/// "최근 진단 기록"은 HomeView "최근 분석한 건물"과 똑같이 실제
/// GET /api/v1/diagnoses(+상세) 데이터를 쓴다 — 예전엔 "저장된 진단 기록이
/// 없습니다"가 항상 고정으로 박혀 있었다.
struct MyPageView: View {
    @Environment(AuthState.self) private var auth
    @State private var historyState: DiagnosisHistoryState = .notLoggedIn

    var body: some View {
        if auth.isLoggedIn {
            profile
        } else {
            LoginView()
        }
    }

    private var profile: some View {
        VStack(spacing: 0) {
            HStack {
                Text("마이페이지").font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(auth.displayName)님").font(.system(size: 18, weight: .bold))
                Text("GreenScan에서 이 집의 변화를 확인해보세요.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.brand50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 21)

            VStack(alignment: .leading, spacing: 8) {
                Text("최근 진단 기록").font(.system(size: 15, weight: .semibold))
                historyContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 21)
            .padding(.top, 24)

            Spacer()

            Button {
                auth.logout()
            } label: {
                Text("로그아웃")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .task(id: auth.sessionToken) {
            await loadHistory()
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        switch historyState {
        case .notLoggedIn:
            Text(
                auth.sessionToken == nil
                    ? "오프라인 데모 계정은 진단 기록을 불러올 수 없어요."
                    : "진단 기록을 불러오는 중..."
            )
            .font(.system(size: 13)).foregroundStyle(.secondary)
        case .loading:
            ProgressView().padding(.top, 4)
        case .failed:
            Text("진단 기록을 불러오지 못했어요.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        case .loaded(let items) where items.isEmpty:
            Text("저장된 진단 기록이 없습니다.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        case .loaded(let items):
            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                            Text(item.dateText).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let reductionRatePercent = item.reductionRatePercent {
                            Text("−\(reductionRatePercent)%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "176b52"))
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "535353").opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    @MainActor
    private func loadHistory() async {
        guard let token = auth.sessionToken else {
            historyState = .notLoggedIn
            return
        }

        historyState = .loading
        do {
            let summaries = try await DiagnosesAPI.list(token: token)
            let recentSummaries = Array(summaries.prefix(10))
            let regionNames = (try? await ReferenceAPI.regions())
                .map { Dictionary(uniqueKeysWithValues: $0.map { ($0.region_id, $0.display_name) }) } ?? [:]

            var items: [DiagnosisHistoryItem] = []
            for summary in recentSummaries {
                let detail = try? await DiagnosesAPI.detail(id: summary.diagnosis_id, token: token)
                let topScenario = detail?.calculation_result.scenarios.min { $0.priority < $1.priority }
                items.append(
                    DiagnosisHistoryItem(
                        id: summary.diagnosis_id,
                        title: "\(BuildingTypeLabel.label(for: summary.building_type_key)) · \(regionNames[summary.region_id] ?? summary.region_id)",
                        dateText: Self.formatDate(summary.created_at),
                        reductionRatePercent: topScenario.map { Int(($0.reduction_rate * 100).rounded()) }
                    )
                )
            }
            historyState = .loaded(items)
        } catch {
            historyState = .failed
        }
    }

    private static func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: isoString) ?? {
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: isoString)
        }()
        guard let date else { return String(isoString.prefix(10)) }

        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "yyyy.MM.dd"
        return outFormatter.string(from: date)
    }
}

private enum DiagnosisHistoryState {
    case notLoggedIn
    case loading
    case loaded([DiagnosisHistoryItem])
    case failed
}

private struct DiagnosisHistoryItem: Identifiable {
    let id: UUID
    let title: String
    let dateText: String
    let reductionRatePercent: Int?
}

#Preview {
    MyPageView().environment(AuthState())
}
