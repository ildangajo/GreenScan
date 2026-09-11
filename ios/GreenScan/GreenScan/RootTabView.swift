import SwiftUI

/// frontend/src/components/ui/BottomNav.tsx의 5개 탭을 그대로 옮김.
/// 아이콘은 SF Symbols가 아니라 웹 사이트가 쓰는 것과 완전히 같은 획 굵기(1.8)
/// 선 아이콘 — BottomNav.tsx의 NavIcon() 안 SVG path를 그대로 내보내서
/// Assets.xcassets에 템플릿 이미지로 넣었다(nav-home/map/saved/news/mypage).
enum AppTab: Hashable {
    case home, map, saved, news, mypage
}

struct RootTabView: View {
    @Environment(AuthState.self) private var auth
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("홈", image: "nav-home") }
                .tag(AppTab.home)

            PlaceholderView(title: "위치")
                .tabItem { Label("위치", image: "nav-map") }
                .tag(AppTab.map)

            SavedView()
                .tabItem { Label("저장", image: "nav-saved") }
                .tag(AppTab.saved)

            RecommendationView()
                .tabItem { Label("추천", image: "nav-news") }
                .tag(AppTab.news)

            MyPageView()
                .tabItem { Label("마이페이지", image: "nav-mypage") }
                .tag(AppTab.mypage)
        }
        // 웹 BottomNav.tsx: 활성 탭은 text-neutral-900(거의 검정), 비활성은 text-neutral-400
        .tint(Color(hex: "111827"))
        // PM 지시(2026-09-11): 로그인하면 마이페이지에 머무르지 말고 홈으로 이동
        .onChange(of: auth.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn { selectedTab = .home }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text("찍먹 스켈레톤 — 아직 미구현")
                .foregroundStyle(.secondary)
        }
    }
}
