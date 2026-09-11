import SwiftUI

/// frontend/src/api/auth.ts의 포팅 — 실제 POST /api/v1/auth/login을 호출한다.
/// 토큰은 앱이 살아있는 동안만 메모리에 들고 있는다(웹의 sessionStorage와
/// 같은 수명 — 앱을 다시 켜면 재로그인해야 한다는 뜻).
///
/// 데모 계정(admin1234 / 1234, PM 지시 2026-09-11)은 남겨뒀지만, 이제는
/// "네트워크 자체가 안 될 때"만 쓰는 오프라인 폴백이다 — 실제 서버가 401을
/// 주면(즉 그 계정이 진짜로 없거나 비번이 틀리면) 폴백하지 않고 있는 그대로
/// 에러를 보여준다. 해커톤 발표 중 와이파이가 불안정해도 데모가 끊기지
/// 않게 하려는 안전장치일 뿐, 정상적인 경우엔 항상 실서버로 로그인한다.
@Observable
final class AuthState {
    static let demoLoginId = "admin1234"
    static let demoPassword = "1234"

    var isLoggedIn = false
    var isLoggingIn = false
    var displayName = "사용자"
    /// 로그인 실패 시 LoginView에 보여줄 메시지
    var loginError: String?
    /// 로그인 성공 시 받은 세션 토큰. 데모 오프라인 폴백으로 로그인했을 땐 nil.
    private(set) var sessionToken: String?

    @MainActor
    func login(loginId: String, password: String) async {
        loginError = nil
        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            let result = try await AuthAPI.login(loginId: loginId, password: password)
            sessionToken = result.session_token
            displayName = (result.display_name?.isEmpty == false) ? result.display_name! : loginId
            isLoggedIn = true
        } catch {
            if loginId == Self.demoLoginId, password == Self.demoPassword, Self.isNetworkFailure(error) {
                sessionToken = nil
                displayName = loginId
                isLoggedIn = true
                return
            }
            loginError = (error as? ApiError)?.message ?? "로그인에 실패했습니다. 네트워크 상태를 확인해주세요."
        }
    }

    @MainActor
    func logout() {
        let token = sessionToken
        isLoggedIn = false
        displayName = "사용자"
        sessionToken = nil
        guard let token else { return }
        Task {
            try? await AuthAPI.logout(token: token)
        }
    }

    /// ApiError(서버가 응답은 했지만 401/422 등을 준 경우)는 실제 인증 실패이므로
    /// 폴백 대상이 아니다. URLError(연결 자체가 안 된 경우)만 폴백 대상으로 본다.
    private static func isNetworkFailure(_ error: Error) -> Bool {
        error is URLError
    }
}
