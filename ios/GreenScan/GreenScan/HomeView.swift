import SwiftUI

private let fabMenuItems: [(key: String, label: String)] = [
    ("terms", "이용약관"),
    ("support", "고객센터"),
]

/// "최근 분석한 건물" 섹션의 로딩 상태. 목업이었던 이전 버전과 달리, 이제는
/// 실제 GET /api/v1/diagnoses 응답을 그대로 반영한다 — 로그인하지 않았거나
/// (오프라인 데모 계정 포함) 진단 이력이 없으면 빈 상태를 정직하게 보여준다.
private enum RecentBuildingsState {
    case notLoggedIn
    case loading
    case loaded([RecentBuilding])
    case failed
}

/// 웹 버전 frontend/src/features/home/HomePage.tsx의 포팅.
/// 웹의 핵심 인터랙션 두 가지를 SwiftUI 방식으로 그대로 옮겼다:
/// 1) 히어로 배너는 고정 배경으로 깔려 있고, "최근 분석한 건물" 시트가 그
///    위를 스크롤로 덮으며 올라와 검색바 바로 아래(pinned section header)에서
///    멈춘 뒤로는 카드 리스트만 평범히 스크롤된다 (웹의 absolute 스페이서 +
///    position:sticky 트릭 → GeometryReader 높이 계산 + LazyVStack
///    pinnedViews 로 대응).
/// 2) 우하단 + 버튼을 누르면 이용약관/고객센터 원이 위로 갈수록 옅어지는
///    색으로 순차 등장하는 스피드다이얼 메뉴.
struct HomeView: View {
    @Environment(AuthState.self) private var auth
    @State private var fabOpen = false
    @State private var recentState: RecentBuildingsState = .notLoggedIn

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                GeometryReader { geo in
                    // 웹의 aspectRatio: "359 / 190" — 좌우 16pt 패딩을 뺀 너비 기준으로
                    // 같은 비율의 높이를 계산해 히어로와 스페이서에 동일하게 쓴다.
                    let heroHeight = (geo.size.width - 32) * 190 / 359

                    ZStack(alignment: .top) {
                        NavigationLink(destination: AiDiagnosisView()) {
                            heroBanner
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: heroHeight)

                        ScrollView {
                            VStack(spacing: 0) {
                                // 히어로와 같은 높이의 투명 스페이서. allowsHitTesting(false)로
                                // 이 구간의 탭은 아래 히어로(NavigationLink)로 그대로 전달된다.
                                Color.clear
                                    .frame(height: heroHeight)
                                    .allowsHitTesting(false)

                                // 헤더는 pinnedViews로 검색바 바로 아래에 고정되고, 카드는 그
                                // 밑에서 평범하게 스크롤된다(웹의 position:sticky와 동일한
                                // 효과). 알려진 제약: 헤더가 고정되는 첫 순간 히어로가 한 프레임
                                // 살짝 비치는 시각적 버그가 남아있다 — 스크롤 자체와 카드 목록
                                // 동작에는 영향 없음.
                                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                    Section {
                                        recentBuildingsContent
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 112)
                                            .background(Color(.systemBackground))
                                    } header: {
                                        recentHeader
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                fab
            }
        }
        .task(id: auth.sessionToken) {
            await loadRecentBuildings()
        }
    }

    @ViewBuilder
    private var recentBuildingsContent: some View {
        switch recentState {
        case .notLoggedIn:
            emptyState(
                message: auth.isLoggedIn
                    ? "오프라인 데모 계정은 최근 분석 내역을 불러올 수 없어요."
                    : "로그인하면 최근 분석한 건물을 볼 수 있어요."
            )
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        case .failed:
            emptyState(message: "최근 분석 내역을 불러오지 못했어요.")
        case .loaded(let buildings) where buildings.isEmpty:
            emptyState(message: "아직 분석한 건물이 없어요. AI 진단을 시작해보세요.")
        case .loaded(let buildings):
            VStack(spacing: 16) {
                ForEach(buildings) { building in
                    RecentBuildingCard(building: building)
                }
            }
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    @MainActor
    private func loadRecentBuildings() async {
        guard let token = auth.sessionToken else {
            recentState = .notLoggedIn
            return
        }

        recentState = .loading
        do {
            let summaries = try await DiagnosesAPI.list(token: token)
            let recentSummaries = Array(summaries.prefix(5))
            let regionNames = (try? await ReferenceAPI.regions())
                .map { Dictionary(uniqueKeysWithValues: $0.map { ($0.region_id, $0.display_name) }) } ?? [:]

            var buildings: [RecentBuilding] = []
            for summary in recentSummaries {
                let detail = try? await DiagnosesAPI.detail(id: summary.diagnosis_id, token: token)
                let topScenario = detail?.calculation_result.scenarios.min { $0.priority < $1.priority }
                buildings.append(
                    RecentBuilding(
                        id: summary.diagnosis_id,
                        title: "\(BuildingTypeLabel.label(for: summary.building_type_key)) · \(regionNames[summary.region_id] ?? summary.region_id)",
                        dateText: Self.formatDate(summary.created_at),
                        reductionRatePercent: topScenario.map { Int(($0.reduction_rate * 100).rounded()) }
                    )
                )
            }
            recentState = .loaded(buildings)
        } catch {
            recentState = .failed
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

    // 헤더는 sticky(pinned)로 뜨는 순간 리스트 흐름에서 분리되므로, 둥근 위쪽
    // 모서리 + 흰 배경 + 그림자는 부모가 아니라 헤더 자신에게 줘야 한다
    // (안 그러면 고정된 뒤에 모서리가 사라짐 — 웹에서도 같은 이유로 헤더에 직접 줬다).
    private var recentHeader: some View {
        HStack {
            Text("최근 분석한 건물").font(.system(size: 14, weight: .medium)).foregroundStyle(Color(hex: "535353"))
            Spacer()
            HStack(spacing: 2) {
                Text("전체보기")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(hex: "176b52"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
    }

    /// + 버튼 — 누르면 서브메뉴 원이 위로 부드럽게 떠오르고, FAB에서 멀어질수록
    /// (위로 갈수록) 색이 옅어진다 (Figma node 28:755).
    private var fab: some View {
        VStack(alignment: .trailing, spacing: 12) {
            ForEach(Array(fabMenuItems.enumerated()), id: \.element.key) { index, item in
                let distanceFromFab = fabMenuItems.count - 1 - index
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { fabOpen = false }
                } label: {
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(hex: "2fcbaa").opacity(0.8)))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                }
                .opacity(fabOpen ? 1 : 0)
                .scaleEffect(fabOpen ? 1 : 0.75)
                .offset(y: fabOpen ? 0 : 16)
                .allowsHitTesting(fabOpen)
                .animation(.easeOut(duration: 0.3).delay(fabOpen ? Double(distanceFromFab) * 0.06 : 0), value: fabOpen)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { fabOpen.toggle() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.brand400))
                    .shadow(color: Color.brand400.opacity(0.3), radius: 8, y: 2)
                    .rotationEffect(.degrees(fabOpen ? 45 : 0))
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 96)
        // 메뉴 열렸을 때 바깥(화면 전체)을 탭하면 닫힌다.
        .background(alignment: .topLeading) {
            if fabOpen {
                Color.black.opacity(0.001)
                    .frame(width: 2000, height: 2000)
                    .offset(x: -1900, y: -1900)
                    .onTapGesture { withAnimation { fabOpen = false } }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("어떤 건물을 찾으시나요?")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.brand100, lineWidth: 1))

            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Image(systemName: "bell")
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -4, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            Image("home-hero-house")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.8)
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("AI 진단 시작하기").font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(.systemBackground))
                .foregroundStyle(.primary)
                .clipShape(Capsule())

                Spacer()

                Text("이런 리모델링\n가능하다고?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// GET /api/v1/diagnoses(+상세)로 조립한 실제 진단 이력 1건. 사진은 서버에
/// 원본을 저장하지 않으므로(PRD) 썸네일은 항상 장식용 그라디언트다.
private struct RecentBuilding: Identifiable {
    let id: UUID
    let title: String
    let dateText: String
    /// 상세 조회가 실패했거나 시나리오가 없으면 nil — 이 경우 숫자를 지어내지
    /// 않고 그냥 안 보여준다.
    let reductionRatePercent: Int?
}

private struct RecentBuildingCard: View {
    let building: RecentBuilding

    var body: some View {
        HStack(spacing: 13) {
            LinearGradient(colors: [Color(hex: "e4efe9"), Color(hex: "7fae93")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 101, height: 85)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text(building.title).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "535353"))

                HStack(spacing: 8) {
                    Text("분석완료")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "2fcbaa").opacity(0.8))
                        .clipShape(Capsule())
                    Text(building.dateText)
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "535353").opacity(0.8))
                }

                if let reductionRatePercent = building.reductionRatePercent {
                    metricBox(label: "에너지 절감률", value: "\(reductionRatePercent)%", valueSize: 16)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 6)
        .frame(height: 98)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .overlay(alignment: .trailing) {
            Image("home-chevron")
                .resizable()
                .frame(width: 4.5, height: 9)
                .padding(.trailing, 14)
        }
    }

    private func metricBox(label: String, value: String, valueSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 5)).foregroundStyle(.secondary)
            Text(value).font(.system(size: valueSize, weight: .semibold)).foregroundStyle(Color(hex: "176b52"))
        }
        .padding(6)
        .frame(width: 81, height: 39, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 1)
    }
}

#Preview {
    HomeView().environment(AuthState())
}
