import SwiftUI

/// 液态玻璃的统一入口。
/// iOS 26 用系统原生 `glassEffect`（有光折射、随陀螺仪的高光、按压缩放）；
/// 低版本退回系统材质，观感差一档但不崩。
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 22

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}
