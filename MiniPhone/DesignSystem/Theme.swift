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

    // MARK: - 浅色 App 的语义色

    /// systemGroupedBackground。浅色 App 的页面底色。
    static let groupedBackground = Color(red: 0.949, green: 0.949, blue: 0.969)
    /// 分组列表里的行与卡片。
    static let rowSurface = Color.white
    /// 浅色 App 的主文字。
    static let label = Color.black
    /// 浅色 App 的次文字。
    static let secondaryLabel = Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.6)
    /// 行内分隔线。
    static let separator = Color(red: 0.776, green: 0.776, blue: 0.784)
    /// 系统蓝。浅色 App 的 tint。
    static let tint = Color(red: 0.0, green: 0.478, blue: 1.0)

    /// 设置页、场景页左侧彩色小图标的底色。视图里不写字面色值，都从这里取。
    enum IconTint {
        static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        static let purple = Color(red: 0.45, green: 0.40, blue: 0.80)
        static let pink = Color(red: 0.90, green: 0.35, blue: 0.42)
        static let gray = Color(red: 0.48, green: 0.50, blue: 0.55)
        static let green = Color(red: 0.35, green: 0.60, blue: 0.40)
        static let indigo = Color(red: 0.55, green: 0.42, blue: 0.78)
    }

    /// 阴影只有三档。浅色分组列表默认不用——给每行都加阴影，浅底上会叠出一圈灰边。
    enum ShadowStyle {
        case none
        case soft
        case lifted

        var color: Color {
            switch self {
            case .none: return .clear
            case .soft: return Color.black.opacity(0.06)
            case .lifted: return Color.black.opacity(0.12)
            }
        }

        var radius: CGFloat {
            switch self {
            case .none: return 0
            case .soft: return 6
            case .lifted: return 16
            }
        }

        var y: CGFloat {
            switch self {
            case .none: return 0
            case .soft: return 2
            case .lifted: return 8
            }
        }
    }
}
