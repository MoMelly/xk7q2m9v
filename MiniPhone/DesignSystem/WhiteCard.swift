import SwiftUI

/// 白色玻璃卡片的唯一入口。
///
/// 外壳强制深色模式，系统 `Form` 单元格会跟着变黑；显式铺白底 + 细白描边
/// 才能拿到仿系统设置页的观感，且不受 preferredColorScheme 影响。
struct WhiteCard: ViewModifier {
    var cornerRadius: CGFloat = PhoneMetrics.Radius.card
    /// 默认不投影。分组列表给每行都加阴影，浅底上会叠出一圈灰边，这是「脏」的主要来源。
    var shadow: Theme.ShadowStyle = .none

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(shape.fill(Theme.rowSurface))
            .clipShape(shape)
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

extension View {
    func whiteCard(
        cornerRadius: CGFloat = PhoneMetrics.Radius.card,
        shadow: Theme.ShadowStyle = .none
    ) -> some View {
        modifier(WhiteCard(cornerRadius: cornerRadius, shadow: shadow))
    }
}
