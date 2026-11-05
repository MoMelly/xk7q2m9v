import SwiftUI

/// 一个圆滚滚的西瓜。
///
/// 不用图片：App 图标和帖子默认头像都要用它，尺寸从 18 到 60 都有，
/// 位图在桌面那个尺寸上会糊。用形状画出来，任何尺寸都干净。
struct WatermelonMark: View {
    var size: CGFloat = 40

    /// 籽的位置按比例给，换尺寸时不会挤成一团。
    private let seeds: [(x: CGFloat, y: CGFloat, angle: Double)] = [
        (-0.22, -0.10, -18),
        (0.10, -0.20, 12),
        (0.24, 0.10, -8),
        (-0.06, 0.14, 20),
        (-0.30, 0.14, 8)
    ]

    var body: some View {
        ZStack {
            // 绿皮
            Circle()
                .fill(Theme.Watermelon.rind)

            // 白瓤，只露一圈
            Circle()
                .fill(Theme.Watermelon.pith)
                .padding(size * 0.075)

            // 红瓤
            Circle()
                .fill(Theme.Watermelon.flesh)
                .padding(size * 0.13)

            // 顶部一层薄高光，和桌面图标一样是「从上面打下来的光」
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(size * 0.13)

            // 小尺寸下籽会糊成一团黑点，只留三颗反而看得出来是西瓜。
            ForEach(Array(seeds.prefix(size < 20 ? 3 : seeds.count).enumerated()), id: \.offset) { _, seed in
                Capsule()
                    .fill(Theme.Watermelon.seed.opacity(0.82))
                    .frame(width: size * 0.055, height: size * 0.10)
                    .rotationEffect(.degrees(seed.angle))
                    .offset(x: size * seed.x, y: size * seed.y)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
