import SwiftUI

/// frontend/tailwind.config.js의 brand.* 팔레트를 그대로 옮김.
extension Color {
    static let brand50 = Color(hex: "EAFBF3")
    static let brand100 = Color(hex: "D3F5E6")
    static let brand300 = Color(hex: "8FE0BA")
    static let brand400 = Color(hex: "2FCB8F")
    static let brand500 = Color(hex: "1FB07A")
    static let brand600 = Color(hex: "15966A")

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
