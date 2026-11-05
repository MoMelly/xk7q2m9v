import SwiftUI

/// 一块切开的西瓜，半圆，平口朝上。
///
/// 不用图片：桌面图标、默认头像、头像角标都要它，尺寸从 16 到 60 都有，
/// 位图在桌面那个尺寸上会糊。用形状画出来，任何尺寸都干净。
///
/// 三层同圆心：绿皮 → 白瓤 → 红瓤。三层的平口都在同一条线上，
/// 所以绿边只在弧上出现，收口处自然尖细——真切片就是这个样子。
/// 白瓤刻意留得很薄：厚了像塑料模型，薄薄一条才像刚切开的断面。
struct WatermelonMark: View {
    var size: CGFloat = 40

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

            // 弧上那道玻璃似的反光：沿外缘走一圈，只在左半边亮
            SliceShape(radius: radius * 0.985, center: center)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .white.opacity(0.05), .white.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.8, size * 0.022)
                )
                .blendMode(.plusLighter)

            seedsLayer(radius: radius, center: center)
        }
        .frame(width: size, height: size)
    }

    /// 红瓤：顶部偏亮、往下压深，再叠一层偏心高光和一道斜向玻璃反光。
    /// 通透感全靠这几层叠出来，纯色红瓤会像贴在图标上的一块纸。
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
                    RadialGradient(
                        colors: [.white.opacity(0.42), .clear],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: radius * 0.95
                    )
                )

            // 斜向反光条，从左上切到右下，模拟玻璃表面的一道高光
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: radius * 1.5, height: max(1.5, radius * 0.10))
                .rotationEffect(.degrees(-18))
                .offset(x: -radius * 0.18, y: radius * 0.10)
                .blur(radius: max(0.6, radius * 0.03))
                .blendMode(.plusLighter)

            // 弧底一道回光，切片才像有厚度
            SliceShape(radius: radius * 0.86, center: center)
                .stroke(.white.opacity(0.16), lineWidth: max(0.6, radius * 0.03))
                .blur(radius: max(0.4, radius * 0.02))
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
