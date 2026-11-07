import SwiftUI

/// 液态玻璃的统一入口。
/// iOS 26 用系统原生 `glassEffect`（有光折射、随陀螺仪的高光、按压缩放）；
/// 低版本退回系统材质，观感差一档但不崩。
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    /// 垫进玻璃的底色。系统材质跟着外壳的色彩方案走：外壳是深色时，
    /// 浅色物件上的玻璃会被压成一块深灰。垫一层白（日间）或一层薄白
    /// （夜间）把明暗拉回物件自己的档位，而不是靠外面再叠膜。
    var tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill(tint ?? .clear))
                .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}
