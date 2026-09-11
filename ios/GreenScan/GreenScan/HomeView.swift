import SwiftUI

private let fabMenuItems: [(key: String, label: String)] = [
    ("terms", "이용약관"),
    ("support", "고객센터"),
]

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
    @State private var fabOpen = false

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
                                        VStack(spacing: 16) {
                                            ForEach(RecentBuilding.samples) { building in
                                                RecentBuildingCard(building: building)
                                            }
                                        }
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

private struct RecentBuilding: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let reductionRate: Int
    let costText: String
    let thumb: String?

    // 웹 MOCK_RECENT와 동일 — 5~8번은 웹에서도 "스크롤 동작 테스트용"으로 추가된 목업이다.
    static let samples = [
        RecentBuilding(title: "서울시 강남구 OO빌딩", date: "2026.07.02", reductionRate: 52, costText: "1,300만원", thumb: "home-building-gangnam"),
        RecentBuilding(title: "서울시 강북구 OO카페", date: "2024.04.22", reductionRate: 24, costText: "620만원", thumb: "home-building-gangbuk"),
        RecentBuilding(title: "서울시 강서구 OO빌라", date: "2025.11.12", reductionRate: 21, costText: "430만원", thumb: nil),
        RecentBuilding(title: "서울시 송파구 OO빌딩", date: "2026.09.09", reductionRate: 60, costText: "1,850만원", thumb: nil),
        RecentBuilding(title: "서울시 서초구 OO오피스텔", date: "2026.03.15", reductionRate: 38, costText: "980만원", thumb: nil),
        RecentBuilding(title: "서울시 마포구 OO상가", date: "2025.08.21", reductionRate: 45, costText: "1,120만원", thumb: nil),
        RecentBuilding(title: "서울시 영등포구 OO빌딩", date: "2024.12.02", reductionRate: 29, costText: "760만원", thumb: nil),
        RecentBuilding(title: "서울시 성동구 OO주택", date: "2026.01.30", reductionRate: 55, costText: "1,470만원", thumb: nil),
    ]
}

private struct RecentBuildingCard: View {
    let building: RecentBuilding

    var body: some View {
        HStack(spacing: 13) {
            Group {
                if let thumb = building.thumb {
                    Image(thumb).resizable().aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [Color(hex: "e4efe9"), Color(hex: "7fae93")], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
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
                    Text(building.date)
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "535353").opacity(0.8))
                }

                // 웹은 절감률/비용 값 폰트 크기를 다르게 줘서(16px vs 14px)
                // 절감률 숫자가 더 눈에 띄게 했다 — 그 위계를 그대로 따른다.
                HStack(spacing: 6) {
                    metricBox(label: "에너지 절감률", value: "\(building.reductionRate)%", valueSize: 16)
                    metricBox(label: "예상 비용", value: building.costText, valueSize: 14)
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
    HomeView()
}
