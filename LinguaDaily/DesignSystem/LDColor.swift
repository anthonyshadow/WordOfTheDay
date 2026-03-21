import SwiftUI

enum LDColor {
    static let background = Color(hex: "#F4F5F2")
    static let surface = Color(hex: "#FFFFFF")
    static let surfaceMuted = Color(hex: "#EEF1EB")
    static let inkPrimary = Color(hex: "#1D2723")
    static let inkSecondary = Color(hex: "#53615A")
    static let accent = Color(hex: "#243B31")
    static let accentSoft = Color(hex: "#DCE8DF")
    static let cardWarm = LinearGradient(
        colors: [Color(hex: "#FDF4E8"), Color(hex: "#FBEFD8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let success = Color(hex: "#1B8F5A")
    static let danger = Color(hex: "#B9423B")
    static let warning = Color(hex: "#C68B2A")
}

extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
