import SwiftUI

/// 웹 버전 frontend/src/features/home/HomePage.tsx의 "찍먹" 포팅.
/// 히어로가 주소 위를 덮는 스크롤 인터랙션 같은 커스텀 애니메이션은 스켈레톤
/// 단계라 아직 없고, 구조(검색바 고정 + 히어로 + 최근 분석한 건물 리스트 +
/// 하단 탭)만 옮겼다.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NavigationLink(destination: AiDiagnosisView()) {
                            heroBanner
                        }
                        .buttonStyle(.plain)
                        recentSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .background(Color(.systemBackground))
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
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 분석한 건물").font(.system(size: 14, weight: .medium))
                Spacer()
                HStack(spacing: 2) {
                    Text("전체보기")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "176b52"))
            }

            ForEach(RecentBuilding.samples) { building in
                RecentBuildingCard(building: building)
            }
        }
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
