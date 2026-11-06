import SwiftUI

/// 「我的主页」顶部那张整幅背景图。
///
/// 不引图片素材：几团模糊色斑叠在低饱和渐变上，再压一层斜纹和上下收边，
/// 靠代码画出照片那种层次。`variant` 换整套色相与斑点位置，右上角「换一张」
/// 只是把它加一，不需要任何持久化。
struct ProfileBackdrop: View {
    let variant: Int
    let height: CGFloat

    private struct Scheme {
        let top: Color
        let bottom: Color
        let blobs: [Color]
    }

    /// 全部保持浅色：顶栏和返回按钮是深色字，底色压暗了就糊成一片。
    private static let schemes: [Scheme] = [
        Scheme(top: Color(red: 0.99, green: 0.92, blue: 0.91),
               bottom: Color(red: 0.93, green: 0.78, blue: 0.83),
               blobs: [Color(red: 1.00, green: 0.81, blue: 0.71),
                       Color(red: 0.86, green: 0.74, blue: 0.90),
                       Color(red: 0.99, green: 0.95, blue: 0.82)]),
        Scheme(top: Color(red: 0.90, green: 0.96, blue: 0.94),
               bottom: Color(red: 0.76, green: 0.89, blue: 0.86),
               blobs: [Color(red: 0.99, green: 0.94, blue: 0.76),
                       Color(red: 0.70, green: 0.87, blue: 0.83),
                       Color(red: 0.96, green: 0.84, blue: 0.88)]),
        Scheme(top: Color(red: 0.92, green: 0.95, blue: 0.99),
               bottom: Color(red: 0.79, green: 0.85, blue: 0.96),
               blobs: [Color(red: 0.99, green: 0.88, blue: 0.86),
                       Color(red: 0.80, green: 0.90, blue: 0.99),
                       Color(red: 0.92, green: 0.83, blue: 0.96)]),
        Scheme(top: Color(red: 0.99, green: 0.96, blue: 0.88),
               bottom: Color(red: 0.94, green: 0.86, blue: 0.72),
               blobs: [Color(red: 0.91, green: 0.95, blue: 0.83),
                       Color(red: 1.00, green: 0.84, blue: 0.76),
                       Color(red: 0.85, green: 0.88, blue: 0.97)])
    ]

    private var scheme: Scheme {
        Self.schemes[abs(variant) % Self.schemes.count]
    }

    /// 斑点按 variant 轮换位置并带一点抖动，换一张时不会只是换色不换构图。
    private func blob(_ index: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        let base: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.30, -0.20, 0.76),
            (0.34, 0.08, 0.88),
            (-0.12, 0.48, 0.62)
        ]
        let pick = base[(index + abs(variant)) % base.count]
        let jitter = CGFloat((abs(variant) * 3 + index * 5) % 5) * 0.018
        return (pick.0 + jitter, pick.1 + jitter, pick.2)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                LinearGradient(
                    colors: [scheme.top, scheme.bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(Array(scheme.blobs.enumerated()), id: \.offset) { index, color in
                    let spec = blob(index)
                    let side = width * spec.size
                    Circle()
                        .fill(color.opacity(0.88))
                        .frame(width: side, height: side)
                        .offset(x: spec.x * width, y: spec.y * height)
                        .blur(radius: width * 0.10)
                }

                // 斜纹给平面一点颗粒感，纯渐变大色块看着像占位图。
                ProfileBackdropStripes()
                    .opacity(0.14)
                    .blendMode(.plusLighter)

                // 顶边提亮保证状态栏/返回按钮可读；底边压回底色，
                // 让头像压沿的位置不会突然断成一条硬线。
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.20), location: 0),
                        .init(color: .clear, location: 0.22),
                        .init(color: .clear, location: 0.76),
                        .init(color: scheme.bottom.opacity(0.55), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: width, height: height)
        }
        .frame(height: height)
        .clipped()
    }
}

/// 等距斜线，铺满给定尺寸。用 Canvas 而不是一堆旋转 Capsule，
/// 后者在缩放时会把父视图的测量尺寸撑大。
private struct ProfileBackdropStripes: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += 9
            }
            context.stroke(path, with: .color(.white), lineWidth: 1)
        }
    }
}
