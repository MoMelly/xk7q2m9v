import SwiftUI

/// 锁屏数字的玻璃质感。
///
/// 关键是「字本身是玻璃」，不是「字外面套一个玻璃框」：拿字形当遮罩，
/// 玻璃材质只在笔画内可见，壁纸从笔画里透出来，再补一层内发光做出厚度。
/// 之前给 Text 加的是容器玻璃，一眼就能看出来是假的。
struct GlassClock: View {
    let text: String
    var fontSize: CGFloat = PhoneMetrics.lockClockFontSize

    private var glyph: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .monospacedDigit()
    }

    var body: some View {
        ZStack {
            // 玻璃本体。材质采样背后那张壁纸，被字形裁掉，只剩笔画内可见。
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(glyph)

            // 内发光：模拟玻璃厚度，只在笔画里面亮。
            glyph
                .foregroundStyle(.white.opacity(0.55))
                .blur(radius: 5)
                .mask(glyph)

            // 自上而下的柔光，避免整块字过于透明而读不出时间。
            glyph
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.46), .white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 16, y: 6)
        .shadow(color: .white.opacity(0.18), radius: 1, y: -1)
        .accessibilityLabel(text)
    }
}
