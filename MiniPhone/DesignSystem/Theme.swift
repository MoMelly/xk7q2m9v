import SwiftUI

/// 白 + 复古绿的色板。刻意压暗、压低饱和，
/// 避免那种一眼看上去像模板 App 的亮绿色。
enum Theme {
    static let ink = Color(red: 0.07, green: 0.11, blue: 0.10)
    static let deepGreen = Color(red: 0.10, green: 0.22, blue: 0.18)
    static let retroGreen = Color(red: 0.29, green: 0.47, blue: 0.39)
    static let mint = Color(red: 0.62, green: 0.82, blue: 0.71)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)
    /// 错误提示用的暖红。压暗过，深色底上不刺眼。
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.55)

    /// 设置页与场景页的浅色体系。外壳是深色模式，这三个必须写成绝对色值，
    /// 不能用 `.primary` / `.secondary` 之类会跟着配色方案翻转的语义色。
    static let settingsBackground = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let cardSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let secondaryInk = Color(red: 0.43, green: 0.45, blue: 0.48)

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
