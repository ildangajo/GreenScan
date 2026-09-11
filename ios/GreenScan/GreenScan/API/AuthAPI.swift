import Foundation

/// 웹 frontend/src/api/auth.ts와 동일한 계약.
enum AuthAPI {
    struct LoginRequest: Encodable {
        let login_id: String
        let password: String
    }

    struct LoginResponse: Decodable {
        let session_token: String
        let expires_at: String
        let display_name: String?
    }

    static func login(loginId: String, password: String) async throws -> LoginResponse {
        try await APIClient.request(
            path: "/api/v1/auth/login",
            method: "POST",
            body: LoginRequest(login_id: loginId, password: password)
        )
    }

    static func logout(token: String) async throws {
        _ = try await APIClient.request(
            path: "/api/v1/auth/logout",
            method: "POST",
            body: nil,
            token: token
        ) as EmptyResponse
    }
}
