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
}
