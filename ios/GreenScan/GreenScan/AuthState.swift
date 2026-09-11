import SwiftUI

/// frontend/src/api/auth.ts의 아주 단순화된 포팅 — 아직 네트워킹 레이어가 없어서
/// 진짜 로그인 API 호출은 안 하고, 로그인 여부/표시이름만 앱 전역에서 공유한다.
/// 실제 서버 연동은 API 클라이언트를 옮길 때 여기에 붙이면 된다.
///
/// 데모용 하드코딩 계정(PM 지시, 2026-09-11): admin1234 / 1234.
@Observable
final class AuthState {
    static let demoLoginId = "admin1234"
    static let demoPassword = "1234"

    var isLoggedIn = false
    var displayName = "사용자"
    /// 로그인 실패 시 LoginView에 보여줄 메시지
    var loginError: String?

    /// 성공하면 true를 돌려주고 isLoggedIn을 켠다. RootTabView가 이 변화를 보고 홈 탭으로 옮긴다.
    @discardableResult
    func login(loginId: String, password: String) -> Bool {
        guard loginId == Self.demoLoginId, password == Self.demoPassword else {
            loginError = "아이디 또는 비밀번호가 올바르지 않습니다."
            return false
        }
        loginError = nil
        displayName = loginId
        isLoggedIn = true
        return true
    }

    func logout() {
        isLoggedIn = false
        displayName = "사용자"
    }
}
