import SwiftUI

/// 页面底色。
///
/// 外壳固定在深色模式，`preferredColorScheme` 一动就会把聊天页、动态页的
/// 语义色一起翻掉。所以浅色 App 不靠配色方案翻转，而是显式声明这一层，
/// 标题、正文、分隔线都取这里的绝对色值。
enum AppSurface {
    case light
    case dark
    case glass

    var background: Color {
        switch self {
        case .light: return Theme.groupedBackground
        case .dark: return Theme.ink
        case .glass: return .clear
        }
    }

    var label: Color {
        switch self {
        case .light: return Theme.label
        case .dark, .glass: return .white
        }
    }

    var secondaryLabel: Color {
        switch self {
        case .light: return Theme.secondaryLabel
        case .dark, .glass: return .white.opacity(0.7)
        }
    }

    var rowSurface: Color {
        switch self {
        case .light: return Theme.rowSurface
        case .dark, .glass: return .white.opacity(0.1)
        }
    }

    var separator: Color {
        switch self {
        case .light: return Theme.separator
        case .dark, .glass: return .white.opacity(0.15)
        }
    }

    var tint: Color {
        switch self {
        case .light: return Theme.tint
        case .dark, .glass: return Theme.mint
        }
    }

    /// 这一层要用的配色方案。
    ///
    /// 外壳固定在深色，系统控件（`Toggle` 的标签、`Picker` 的选项、`TextField`
    /// 的占位）都会跟着继承成白字，落在浅色底上就是白底白字。整页声明一次，
    /// 比给每个控件单独补 `foregroundStyle` 可靠——补漏一个就又是一处看不清。
    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark, .glass: return .dark
        }
    }
}
