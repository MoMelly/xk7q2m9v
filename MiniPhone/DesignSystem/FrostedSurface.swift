import SwiftUI

/// 磨砂面。
///
/// 和 `glassSurface` 的分工：玻璃要「有折射、有厚度」，磨砂要「糊住背后的东西」。
/// 同一块底用 `glassEffect` 出来是一层乳白塑料板，用材质 + 一层薄白出来才是
/// 参考图里那种毛玻璃——底色透上来、边缘一圈细高光、阴影几乎没有。
///
/// 数值跟着配色方案走：日间垫白多一点（否则压在浅底上发灰），
/// 夜间只留一点（否则一块白板比灰还假）。
///
/// 白垫的多少再乘一档用户选的厚薄（`ThemeStore.glassFactor`）。
/// 壁纸从浅到深都有人用，固定一个值总有一套不合适。
struct FrostedSurface: ViewModifier {
    var cornerRadius: CGFloat
    /// 日间的白垫比例，0~1。夜间按 `nightScale` 折。
    var white: Double
    var borderWhite: Double
    var shadow: Theme.ShadowStyle

    /// 夜间白垫的折数。夜里再垫厚就是一整块白板。
    private static let nightScale = 0.35

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // 材质本身跟 colorScheme 走。外壳锁深色时，ultraThinMaterial 会算成暗色，
        // 垫多少白最后还是一片灰。这里把材质单独按浅色渲染，出来的才是透亮的毛玻璃。
        let night = ThemeStore.shared.isNight
        let scheme: ColorScheme = night ? .dark : .light
        let scale = ThemeStore.shared.glassFactor
        // 上限压在 0.92：再高就成不透明的白卡，壁纸白设了。
        let fill = min(0.92, (night ? white * Self.nightScale : white) * scale)
        let line = min(0.95, (night ? borderWhite * Self.nightScale : borderWhite) * scale)

        return content
            .background {
                ZStack {
                    shape
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, scheme)
                    shape.fill(Color.white.opacity(fill))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(line), lineWidth: 0.8))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

extension View {
    /// 卡片用的磨砂。
    ///
    /// 白垫得越厚，材质那层灰越明显 —— 材质本身会去饱和，压在白卡片底下就成了灰板。
    /// 所以这里白只垫到能读字为止（0.34），边缘靠一道亮边立住，不靠阴影。
    func frostedCard(
        cornerRadius: CGFloat = PhoneMetrics.Radius.card,
        shadow: Theme.ShadowStyle = .none
    ) -> some View {
        modifier(
            FrostedSurface(
                cornerRadius: cornerRadius,
                white: 0.34,
                borderWhite: 0.62,
                shadow: shadow
            )
        )
    }

    /// 栏位用的磨砂（Dock、悬浮底栏、输入条）：要透出底下的东西，白再少一点。
    func frostedBar(
        cornerRadius: CGFloat = 26,
        shadow: Theme.ShadowStyle = .none
    ) -> some View {
        modifier(
            FrostedSurface(
                cornerRadius: cornerRadius,
                white: 0.20,
                borderWhite: 0.54,
                shadow: shadow
            )
        )
    }
}
