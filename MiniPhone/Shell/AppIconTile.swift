import SwiftUI

/// 单个桌面图标。
///
/// 不引入任何图片素材，用「渐变底座 + 顶部高光 + 内描边 + SF Symbol」拼出
/// iOS 26 那种液态玻璃观感：底色是饱和的，但表面压了一层从顶部打下来的反光，
/// 边缘一圈细白线模拟玻璃的折边。
struct AppIconTile: View {
    let app: PhoneApp
    var size: CGFloat = PhoneMetrics.iconSize
    var showsLabel: Bool = true

    private var cornerRadius: CGFloat { size * 0.224 }

    /// 反光条本身比图标宽，直接放进主 ZStack 会把 ZStack 的测量尺寸撑到 1.6 倍，
    /// 底层圆角渐变也跟着被拉宽；外层 `.frame(width: size)` 只定外框、不裁溢出。
    /// 先塞进固定尺寸容器并裁掉溢出，主 ZStack 量到的才还是 size × size。
    private var sheen: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.30), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 1.6, height: size * 0.26)
                .rotationEffect(.degrees(-32))
                .offset(x: -size * 0.14, y: -size * 0.26)
                .blur(radius: size * 0.02)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    var body: some View {
        VStack(spacing: size * 0.1) {
            iconBody

            if showsLabel {
                Text(app.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            }
        }
    }

    private var iconBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: app.colors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 整体薄雾：把饱和底色提亮成半通透，避免图标看起来像实心塑料块。
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.16))

            // 顶部高光：玻璃表面最强的反射在靠上三分之一的区域。
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.38), location: 0),
                            .init(color: .white.opacity(0.08), location: 0.45),
                            .init(color: .clear, location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)

            // 底部回光，模拟光线穿过玻璃后在底边形成的一道淡痕。
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)

            // 按打开目标判断而不是 id：桌面那份是 `feed`，Dock 那份是 `dock.feed`，
            // 只认 id 会让两处同一个 App 画出两个不一样的图标。
            if app.destination == .scene(.feed) {
                // 西瓜皮不用 SF Symbol，也不用白色圆徽章打底：
                // 切片自己带白瓤收边，落在红底上轮廓已经够清楚，
                // 再垫一个白圆就成了「圆里贴了张图」，反而把通透镜面压死。
                // 红底上先铺一层背光，切片像是嵌在玻璃里而不是贴在上面。
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.30), .clear],
                            center: UnitPoint(x: 0.5, y: 0.38),
                            startRadius: 0,
                            endRadius: size * 0.62
                        )
                    )
                    .blendMode(.plusLighter)

                WatermelonMark(size: size * 0.84)
                    .offset(y: size * 0.02)
                    .shadow(color: .black.opacity(0.22), radius: size * 0.035, y: size * 0.02)

                // 斜穿整个图标的一道反光。玻璃的通透感来自「表面有光在走」，
                // 只提亮边缘的话，中间还是一片实心红。
                sheen
            } else {
                Image(systemName: app.symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(app.symbolTint)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.2), radius: size * 0.08, y: size * 0.04)
    }
}
