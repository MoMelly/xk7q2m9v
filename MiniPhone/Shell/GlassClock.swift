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

    /// 尺寸由这个不可见字形撑开。
    ///
    /// 不能直接把玻璃层当主体：`Rectangle()` 是可伸缩视图，放进 VStack 后
    /// 会吃掉全部剩余高度，字形被垂直居中到屏幕正中，日期和数字之间空出一大片。
    var body: some View {
        glyph
            .opacity(0)
            .overlay { glassLayers }
            .accessibilityLabel(text)
    }

    private var glassLayers: some View {
        ZStack {
            // 玻璃本体。材质采样背后那张壁纸，被字形裁掉，只剩笔画内可见。
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(glyph)

            // 整体提亮，否则深色壁纸上字会发灰，读不出时间。
            glyph
                .foregroundStyle(.white.opacity(0.30))

            // 锐内边：让笔画边缘catch到光，玻璃的厚度感靠这一层。
            glyph
                .foregroundStyle(.white.opacity(0.90))
                .blur(radius: 2)
                .mask(glyph)

            // 柔和内发光，把锐边和中间过渡开。
            glyph
                .foregroundStyle(.white.opacity(0.45))
                .blur(radius: 7)
                .mask(glyph)

            // 自上而下的反射，上半亮、下半收。
            glyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.62), location: 0),
                            .init(color: .white.opacity(0.20), location: 0.55),
                            .init(color: .white.opacity(0.06), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 16, y: 6)
        .shadow(color: .white.opacity(0.18), radius: 1, y: -1)
    }
}
