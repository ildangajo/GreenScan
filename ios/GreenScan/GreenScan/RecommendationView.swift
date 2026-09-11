import SwiftUI

/// frontend/src/features/recommendation/RecommendationPage.tsx 포팅.
/// 카드 이미지는 웹과 동일한(각 블로그 글의 실제 og:image) 에셋을 그대로 썼다.
struct RecommendationView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 21) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: "535353"))
                Text("홈").font(.system(size: 18)).foregroundStyle(Color(hex: "535353"))
                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    AutoRotatingBanner(imageNames: ["recommendation-banner-1", "recommendation-banner-2"])

                    ForEach(NewsItem.samples) { item in
                        Link(destination: item.url) {
                            VStack(alignment: .leading, spacing: 0) {
                                Image(item.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 192)
                                    .clipped()

                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Spacer()
                                    Text("네이버 블로그").font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(Color(.systemBackground))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemBackground))
    }
}

/// 상단 캠페인 배너 — 두 이미지를 몇 초마다 자동으로 넘긴다. 사용자가 직접
/// 스와이프해도 되고(TabView 기본 동작), 그러면 타이머가 다음 틱에 그
/// 지점부터 다시 이어서 자동 재생한다.
private struct AutoRotatingBanner: View {
    let imageNames: [String]
    @State private var index = 0

    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(imageNames.enumerated()), id: \.offset) { offset, name in
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .tag(offset)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onReceive(timer) { _ in
            withAnimation {
                index = (index + 1) % imageNames.count
            }
        }
    }
}

private struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let imageName: String

    static let samples = [
        NewsItem(
            title: "전북 그린리모델링 시작! 군산 익산 전주 창호 교체 KCC창호",
            url: URL(string: "https://blog.naver.com/roen_architecture/224207707955")!,
            imageName: "news-1"
        ),
        NewsItem(
            title: "2026 한샘 그린리모델링 지원 사업 ㅣ오래 된 창호 고민이라면?",
            url: URL(string: "https://blog.naver.com/nkdljy135/224362654859")!,
            imageName: "news-2"
        ),
        NewsItem(
            title: "그린리모델링 이자지원 22일부터 신청 접수 안 하면 후회할 세부 혜택",
            url: URL(string: "https://blog.naver.com/mercy1209/224292728652")!,
            imageName: "news-3"
        ),
    ]
}

#Preview {
    RecommendationView()
}
