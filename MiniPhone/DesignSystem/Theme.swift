import SwiftUI

/// 白 + 复古绿的色板。刻意压暗、压低饱和，
/// 避免那种一眼看上去像模板 App 的亮绿色。
enum Theme {
    static let ink = Color(red: 0.07, green: 0.11, blue: 0.10)
    static let deepGreen = Color(red: 0.10, green: 0.22, blue: 0.18)
    static let retroGreen = Color(red: 0.29, green: 0.47, blue: 0.39)
    static let mint = Color(red: 0.62, green: 0.82, blue: 0.71)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [deepGreen, ink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
