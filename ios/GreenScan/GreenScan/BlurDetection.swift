import UIKit

/// 클라이언트 사전 블러 체크 (api-spec.md 5.0) — 웹 blurDetection.ts 포팅.
///
/// POST /api/v1/photos/analyze는 이 체크를 통과한(또는 사용자가 "그래도
/// 분석하기"를 누른) 사진에 대해서만 호출된다. 라플라시안 분산(Laplacian
/// variance)이 낮을수록 사진이 흐릴 가능성이 높다는 고전적인 블러 판정
/// 방식을 쓴다. 기기에서 즉시 재촬영 안내를 띄우기 위한 용도이며, 서버 쪽
/// 사진 품질 판정(photo_quality)을 대체하지 않는다.
enum BlurDetection {
    /// 정책 확정 필요 (제안값): 흐림 판정 임계값. OpenCV 블러 감지 튜토리얼
    /// 등에서 흔히 쓰이는 기본값을 가져왔으나, 실제 서비스에서 촬영되는
    /// 창호/벽체 사진 샘플로 팀 검증 후 조정해야 한다(웹 쪽과 동일한 미해결
    /// 사항).
    static let defaultVarianceThreshold: Double = 100

    /// 연산량을 억제하기 위해 분석 전 이미지를 축소할 최대 변 길이.
    private static let maxAnalysisDimension: CGFloat = 600

    struct Result {
        let isBlurry: Bool
        let variance: Double
        let threshold: Double
    }

    /// 실패(픽셀을 못 읽었거나 이미지가 너무 작음)하면 nil을 반환한다 — 호출부는
    /// 이 경우 블러 체크를 건너뛰고 서버 분석을 그대로 진행하면 된다(웹의
    /// catch-and-continue와 동일한 정책).
    static func checkBlur(image: UIImage, threshold: Double = defaultVarianceThreshold) -> Result? {
        guard let cgImage = image.cgImage else { return nil }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        guard originalWidth > 0, originalHeight > 0 else { return nil }

        let scale = min(1, maxAnalysisDimension / max(originalWidth, originalHeight))
        let width = max(3, Int((originalWidth * scale).rounded()))
        let height = max(3, Int((originalHeight * scale).rounded()))

        guard let pixels = rgbaPixels(from: cgImage, width: width, height: height) else { return nil }

        let variance = laplacianVariance(pixels: pixels, width: width, height: height)
        return Result(isBlurry: variance < threshold, variance: variance, threshold: threshold)
    }

    private static func rgbaPixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    /// 3x3 라플라시안 커널 [[0,1,0],[1,-4,1],[0,1,0]]을 그레이스케일 이미지에
    /// 적용한 응답값의 분산을 구한다.
    private static func laplacianVariance(pixels: [UInt8], width: Int, height: Int) -> Double {
        var gray = [Double](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Double(pixels[i * 4])
            let g = Double(pixels[i * 4 + 1])
            let b = Double(pixels[i * 4 + 2])
            gray[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        var responses: [Double] = []
        responses.reserveCapacity((width - 2) * (height - 2))
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let sum = -4 * gray[y * width + x]
                    + gray[(y - 1) * width + x]
                    + gray[(y + 1) * width + x]
                    + gray[y * width + (x - 1)]
                    + gray[y * width + (x + 1)]
                responses.append(sum)
            }
        }

        guard !responses.isEmpty else { return .infinity }
        let mean = responses.reduce(0, +) / Double(responses.count)
        let variance = responses.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(responses.count)
        return variance
    }
}
