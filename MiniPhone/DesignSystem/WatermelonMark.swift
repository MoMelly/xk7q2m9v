import SwiftUI

/// 一块切开的西瓜，半圆，平口朝上。
///
/// 不用图片：桌面图标、默认头像、头像角标都要它，尺寸从 16 到 60 都有，
/// 位图在桌面那个尺寸上会糊。用形状画出来，任何尺寸都干净。
///
/// 三层同圆心：绿皮 → 白瓤 → 红瓤。三层的平口都在同一条线上，
/// 所以绿边只在弧上出现，收口处自然尖细——真切片就是这个样子。
/// 白瓤刻意留得很薄：厚了像塑料模型，薄薄一条才像刚切开的断面。
///
/// 光只留两处：红瓤顶部压下来的一层薄亮，和弧左半边一道反光。
/// 叠太多层 plusLighter 会把中间洗成一片白，看着像糊了油。
struct WatermelonMark: View {
    var size: CGFloat = 40
    /// 单色版：给白底 / 黑底图标用。传了颜色就只画一片实心切片加一道内弧，
    /// 不画皮、瓤、籽三层的色差——那三层的灰阶差在小图标上读不出结构，只剩噪点。
    var monochrome: Color? = nil

    /// 切片高度占宽度的比例。半圆的天然比例是 0.5，
    /// 压到 0.56 让弧显得饱满一点，小尺寸下不至于像一弯眉毛。
    private let heightRatio: CGFloat = 0.56

    /// 籽的位置以「半径」为单位，换尺寸时不会挤成一团。
    private let seeds: [(x: CGFloat, y: CGFloat, angle: Double)] = [
        (-0.40, 0.26, -22),
        (0.02, 0.40, 8),
        (0.40, 0.30, 18),
        (-0.14, 0.62, -6),
        (0.20, 0.70, 12)
    ]

    var body: some View {
        let width = size
        let radius = width / 2
        let center = CGPoint(x: width / 2, y: (size - width * heightRatio) / 2 + radius * 0.06)

        ZStack {
            if let monochrome {
                monoSlice(radius: radius, center: center, color: monochrome)
            } else {
                coloredSlice(radius: radius, center: center)
            }
        }
        .frame(width: size, height: size)
    }

    /// 单色切片：一块实心半圆，靠一道更浅的内弧分出「皮」和「瓤」。
    private func monoSlice(radius: CGFloat, center: CGPoint, color: Color) -> some View {
        ZStack {
            SliceShape(radius: radius, center: center)
                .fill(color)

            SliceShape(radius: radius * 0.78, center: center)
                .fill(color.opacity(0.42))
        }
        .compositingGroup()
    }

    /// 彩色切片：绿皮、白瓤、红瓤三层同心。
    private func coloredSlice(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            // 绿皮
            SliceShape(radius: radius, center: center)
                .fill(
                    LinearGradient(
                        colors: [Theme.Watermelon.rindLight, Theme.Watermelon.rind],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 白瓤，只留一条
            SliceShape(radius: radius * 0.93, center: center)
                .fill(Theme.Watermelon.pith)

            // 红瓤
            redFlesh(radius: radius, center: center)

            // 弧上那道反光只走左半边，右半边留在暗处才有体积。
            SliceShape(radius: radius * 0.985, center: center)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.7, size * 0.014)
                )

            seedsLayer(radius: radius, center: center)
        }
    }

    /// 红瓤：上亮下深，再叠一层从平口压下来的薄亮。
    /// 不用径向高光也不叠斜向反光条——那两层在大图标上会互相洗白。
    private func redFlesh(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            SliceShape(radius: radius * 0.86, center: center)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Watermelon.fleshLight,
                            Theme.Watermelon.flesh,
                            Theme.Watermelon.fleshDeep
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            SliceShape(radius: radius * 0.86, center: center)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .compositingGroup()
    }

    /// 籽。小尺寸下籽会糊成一团黑点，只留三颗反而看得出来是西瓜。
    private func seedsLayer(radius: CGFloat, center: CGPoint) -> some View {
        ForEach(Array(seeds.prefix(size < 22 ? 3 : seeds.count).enumerated()), id: \.offset) { _, seed in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Theme.Watermelon.seed.opacity(0.92), Theme.Watermelon.seed.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(1.4, radius * 0.085), height: max(2.4, radius * 0.16))
                .rotationEffect(.degrees(seed.angle))
                .offset(x: radius * seed.x, y: radius * seed.y + center.y - size / 2)
        }
    }
}

/// 半圆：平口在上，弧朝下。
///
/// 用线段逼近而不是 `addArc`：SwiftUI 里 `clockwise` 相对 y 轴向下的坐标系是反的，
/// 写反了会画成上半圆，而这个形状在五个尺寸下都要一致，不赌参数含义。
private struct SliceShape: Shape {
    var radius: CGFloat
    var center: CGPoint

    func path(in rect: CGRect) -> Path {
        let segments = 72
        var path = Path()

        for index in 0...segments {
            let angle = Double.pi * Double(index) / Double(segments)
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
