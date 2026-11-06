import SwiftUI

/// 单个桌面图标。
///
/// 渐变底 + 一层顶部高光 + 一圈细描边，不再叠斜向反光条和背光圆：
/// 那些层在西瓜皮上互相洗白，远看像蒙了一层油。
/// 外层 `.frame` 之后必须 `.clipShape`，否则子视图会把 ZStack 的测量尺寸撑出去。
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

            // 玻璃表面只留这一道从顶部打下来的高光。
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.22), location: 0),
                            .init(color: .white.opacity(0.05), location: 0.42),
                            .init(color: .clear, location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 按打开目标判断而不是 id：桌面那份是 `feed`，Dock 那份是 `dock.feed`，
            // 只认 id 会让两处同一个 App 画出两个不一样的图标。
            if app.destination == .scene(.feed) {
                WatermelonMark(size: size * 0.84)
                    .offset(y: size * 0.02)
                    .shadow(color: .black.opacity(0.16), radius: size * 0.03, y: size * 0.015)
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
                        colors: [.white.opacity(0.42), .white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.2), radius: size * 0.08, y: size * 0.04)
    }
}
