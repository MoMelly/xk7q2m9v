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

            // 字心：一层实心白。
            //
            // 只有材质 + 几层半透明白的话，浅色壁纸（比如粉色）上整组数字
            // 会糊成一片霜，时间根本读不出来。玻璃感留给高光，可读性交给这一层。
            glyph
                .foregroundStyle(.white.opacity(0.92))

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

            // 自上而下的反射，上半亮、下半收。透明度压到很浅，
            // 否则最后一道渐变会把上面的字心又冲淡。
            glyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.30), location: 0),
                            .init(color: .white.opacity(0.08), location: 0.55),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            specular
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.38), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
        .shadow(color: .white.opacity(0.18), radius: 1, y: -1)
    }

    /// 斜着切的一道静态高光。
    ///
    /// 玻璃的质感靠它，但它不移动。原来这道光每 6.5 秒从左扫到右、
    /// 再瞬间跳回左边重新扫——整个数字的白色部分看起来就在左右来回晃。
    /// 锁屏时钟是一块表，不是一块灯牌。
    private var specular: some View {
        glyph
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.40), location: 0.42),
                        .init(color: .white.opacity(0.52), location: 0.5),
                        .init(color: .white.opacity(0.40), location: 0.58),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .mask(glyph)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}
