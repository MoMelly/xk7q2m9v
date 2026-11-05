import SwiftUI

/// 白色玻璃卡片的唯一入口。
///
/// 外壳强制深色模式，系统 `Form` 单元格会跟着变黑；显式铺白底 + 细白描边
/// 才能拿到仿系统设置页的观感，且不受 preferredColorScheme 影响。
struct WhiteCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(shape.fill(Theme.cardSurface))
            .overlay(shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 0.8))
            .shadow(color: Theme.ink.opacity(0.07), radius: 8, y: 3)
    }
}

extension View {
    func whiteCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(WhiteCard(cornerRadius: cornerRadius))
    }
}
