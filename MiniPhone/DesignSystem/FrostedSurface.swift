import SwiftUI

/// 磨砂面。
///
/// 和 `glassSurface` 的分工：玻璃要「有折射、有厚度」，磨砂要「糊住背后的东西」。
/// 同一块底用 `glassEffect` 出来是一层乳白塑料板，用材质 + 一层薄白出来才是
/// 参考图里那种毛玻璃——底色透上来、边缘一圈细高光、阴影几乎没有。
///
/// 数值跟着配色方案走：日间垫白多一点（否则压在浅底上发灰），
/// 夜间只留一点（否则一块白板比灰还假）。
struct FrostedSurface: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var borderColor: Color
    var shadow: Theme.ShadowStyle

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tint)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 0.8))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

extension View {
    /// 卡片用的磨砂：垫白厚一点，读起来干净。
    func frostedCard(
        cornerRadius: CGFloat = PhoneMetrics.Radius.card,
        shadow: Theme.ShadowStyle = .soft
    ) -> some View {
        let night = ThemeStore.shared.isNight
        return modifier(
            FrostedSurface(
                cornerRadius: cornerRadius,
                tint: Color.white.opacity(night ? 0.16 : 0.55),
                borderColor: Color.white.opacity(night ? 0.14 : 0.66),
                shadow: shadow
            )
        )
    }

    /// 栏位用的磨砂（Dock、悬浮底栏、输入条）：要透出底下的东西，白不能垫满。
    func frostedBar(
        cornerRadius: CGFloat = 26,
        shadow: Theme.ShadowStyle = .soft
    ) -> some View {
        let night = ThemeStore.shared.isNight
        return modifier(
            FrostedSurface(
                cornerRadius: cornerRadius,
                tint: Color.white.opacity(night ? 0.10 : 0.28),
                borderColor: Color.white.opacity(night ? 0.12 : 0.58),
                shadow: shadow
            )
        )
    }
}
