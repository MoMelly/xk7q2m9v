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

            Image(systemName: app.symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(app.symbolTint)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
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
