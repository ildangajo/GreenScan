import SwiftUI

/// frontend/src/features/mypage/MyPage.tsx 포팅 — 로그인 안 돼있으면
/// LoginView를 그대로 보여준다(웹의 "세션 없으면 /login으로 리다이렉트"와 같은 효과).
struct MyPageView: View {
    @Environment(AuthState.self) private var auth

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
                Text("GreenScan에서 우리 집의 변화를 확인해보세요.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.brand50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 21)

            VStack(alignment: .leading, spacing: 8) {
                Text("최근 진단 기록").font(.system(size: 15, weight: .semibold))
                Text("저장된 진단 기록이 없습니다.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
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
    }
}

