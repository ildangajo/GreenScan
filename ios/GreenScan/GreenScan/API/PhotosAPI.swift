import Foundation

/// POST /api/v1/photos/analyze — 로그인 불필요, 사진은 서버에 저장되지 않고
/// 분석 후 즉시 폐기된다(api-spec.md 2.3). category별로 즉시 후보값을
/// 돌려주는 동기 API라 사진 업로드와 AI 후보 확인을 한 화면에서 처리한다.
///
/// APIClient.request는 JSON 바디만 다뤄서 multipart/form-data 업로드를
/// 지원하지 않는다 — 이 파일만 URLSession을 직접 쓴다.
enum PhotosAPI {
    enum PhotoCategory: String {
        case window
        case wall
    }

    struct PhotoAnalysisResponse: Decodable {
        let assessment_status: String
        let photo_quality: String
        let component_type: String
        let window_type_candidate: String
        let visible_anomaly_candidate: String
        let needs_user_confirmation: Bool
        let reason_summary: String
        let model_version: String
    }

    static func analyze(category: PhotoCategory, jpegData: Data) async throws -> PhotoAnalysisResponse {
        guard let url = URL(string: "/api/v1/photos/analyze", relativeTo: APIConfig.baseURL) else {
            throw ApiError(message: "잘못된 요청 경로입니다.", status: 0, code: nil)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeBody(boundary: boundary, category: category, jpegData: jpegData)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError(message: "네트워크 응답을 확인할 수 없습니다.", status: 0, code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClient.makeError(status: http.statusCode, data: data)
        }
        return try JSONDecoder().decode(PhotoAnalysisResponse.self, from: data)
    }

    private static func makeBody(boundary: String, category: PhotoCategory, jpegData: Data) -> Data {
        var body = Data()

        func appendText(_ text: String) {
            body.append(text.data(using: .utf8)!)
        }

        appendText("--\(boundary)\r\n")
        appendText("Content-Disposition: form-data; name=\"category\"\r\n\r\n")
        appendText("\(category.rawValue)\r\n")

        appendText("--\(boundary)\r\n")
        appendText("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n")
        appendText("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        appendText("\r\n")

        appendText("--\(boundary)--\r\n")
        return body
    }
}
