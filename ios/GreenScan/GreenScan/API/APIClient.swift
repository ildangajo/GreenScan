import Foundation

/// 웹 frontend/src/api/http.ts와 동일한 계약의 최소 HTTP 클라이언트.
/// - Base URL은 웹 .env의 VITE_API_BASE_URL과 같은 값.
/// - 에러 응답은 백엔드 공통 형식 `{ detail: { error_code, message } }`을 우선
///   읽고, 없으면 최상위 `message`, 그마저 없으면 HTTP 상태 문구를 쓴다.
/// - Authorization 헤더는 반드시 `Bearer <token>` 형식이어야 한다 — 웹 쪽에서
///   이 프리픽스를 빼먹어 401이 나던 버그가 있었다(2026-09-11 브랜치 머지 때
///   발견/수정), 같은 실수를 반복하지 않으려고 여기 명시해둔다.
enum APIConfig {
    static let baseURL = URL(string: "http://3.38.160.29:8000")!
}

struct ApiError: Error, LocalizedError {
    let message: String
    let status: Int
    let code: String?

    var errorDescription: String? { message }
}

private struct ApiErrorBody: Decodable {
    struct Detail: Decodable {
        let error_code: String?
        let message: String?
    }
    let detail: Detail?
    let message: String?
}

enum APIClient {
    static func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        token: String? = nil
    ) async throws -> T {
        // appendingPathComponent는 "?"/"&"까지 문자 그대로 퍼센트 인코딩해버려서
        // 쿼리스트링이 있는 경로(geocode 등)에는 못 쓴다 — URL(string:relativeTo:)로
        // 상대 참조를 그대로 해석해야 쿼리가 살아남는다.
        guard let url = URL(string: path, relativeTo: APIConfig.baseURL) else {
            throw ApiError(message: "잘못된 요청 경로입니다.", status: 0, code: nil)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        if let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError(message: "네트워크 응답을 확인할 수 없습니다.", status: 0, code: nil)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw makeError(status: http.statusCode, data: data)
        }

        if (http.statusCode == 204 || data.isEmpty), let empty = EmptyResponse() as? T {
            return empty
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// JSON이 아닌 요청(예: PhotosAPI의 multipart 업로드)도 같은 에러 응답
    /// 형식을 공유하므로, 파싱 로직을 여기서 공용으로 노출한다.
    static func makeError(status: Int, data: Data) -> ApiError {
        let body = try? JSONDecoder().decode(ApiErrorBody.self, from: data)
        return ApiError(
            message: body?.detail?.message ?? body?.message ?? "요청을 처리하지 못했습니다.",
            status: status,
            code: body?.detail?.error_code
        )
    }
}

/// 응답 본문이 없는 엔드포인트(예: 로그아웃) 호출부에서 `APIClient.request`의
/// 반환 타입으로 쓴다.
struct EmptyResponse: Decodable {}

/// Encodable existential(`any Encodable`)을 JSONEncoder에 바로 넘길 수 있게 감싸는 어댑터.
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeClosure = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
