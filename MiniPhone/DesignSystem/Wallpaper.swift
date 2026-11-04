import SwiftUI

/// 内置壁纸。
///
/// 全部用代码画，不打图片进包体——换主题只是换一组参数。
/// 每张壁纸由「基底渐变 + 若干模糊光斑 + 暗角」三层叠出来，
/// 模拟真机壁纸那种有纵深的明暗分布，而不是一味平的渐变色。
enum WallpaperTheme: String, CaseIterable, Identifiable {
    case midnight
    case forest
    case ember
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "深夜蓝"
        case .forest: return "苔绿"
        case .ember: return "余烬"
        case .graphite: return "石墨"
        }
    }

    /// 基底渐变，左上到右下。
    var baseColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.10, green: 0.16, blue: 0.34),
                Color(red: 0.03, green: 0.05, blue: 0.12)
            ]
        case .forest:
            return [
                Color(red: 0.11, green: 0.25, blue: 0.20),
                Color(red: 0.02, green: 0.06, blue: 0.05)
            ]
        case .ember:
            return [
                Color(red: 0.42, green: 0.18, blue: 0.12),
                Color(red: 0.09, green: 0.04, blue: 0.05)
            ]
        case .graphite:
            return [
                Color(red: 0.22, green: 0.23, blue: 0.25),
                Color(red: 0.05, green: 0.05, blue: 0.06)
            ]
        }
    }

    /// 叠在基底上的光斑。坐标和半径都按屏幕长边的比例给，换个机型不会跑偏。
    var blobs: [WallpaperBlob] {
        switch self {
        case .midnight:
            return [
                WallpaperBlob(x: 0.18, y: 0.12, radius: 0.46, color: Color(red: 0.28, green: 0.46, blue: 0.92)),
                WallpaperBlob(x: 0.86, y: 0.34, radius: 0.38, color: Color(red: 0.44, green: 0.30, blue: 0.78)),
                WallpaperBlob(x: 0.50, y: 0.92, radius: 0.44, color: Color(red: 0.14, green: 0.30, blue: 0.62))
            ]
        case .forest:
            return [
                WallpaperBlob(x: 0.22, y: 0.16, radius: 0.48, color: Color(red: 0.24, green: 0.58, blue: 0.44)),
                WallpaperBlob(x: 0.82, y: 0.58, radius: 0.40, color: Color(red: 0.13, green: 0.36, blue: 0.30)),
                WallpaperBlob(x: 0.44, y: 0.88, radius: 0.42, color: Color(red: 0.52, green: 0.72, blue: 0.44))
            ]
        case .ember:
            return [
                WallpaperBlob(x: 0.76, y: 0.14, radius: 0.44, color: Color(red: 0.92, green: 0.48, blue: 0.22)),
                WallpaperBlob(x: 0.20, y: 0.48, radius: 0.40, color: Color(red: 0.68, green: 0.22, blue: 0.20)),
                WallpaperBlob(x: 0.60, y: 0.90, radius: 0.38, color: Color(red: 0.86, green: 0.38, blue: 0.40))
            ]
        case .graphite:
            return [
                WallpaperBlob(x: 0.30, y: 0.20, radius: 0.50, color: Color(red: 0.42, green: 0.44, blue: 0.48)),
                WallpaperBlob(x: 0.78, y: 0.66, radius: 0.44, color: Color(red: 0.30, green: 0.32, blue: 0.36))
            ]
        }
    }
}

struct WallpaperBlob {
    /// 圆心横向位置，0 到 1。
    let x: CGFloat
    /// 圆心纵向位置，0 到 1。
    let y: CGFloat
    /// 半径，按屏幕长边比例给。
    let radius: CGFloat
    let color: Color
}

/// 壁纸渲染层。
struct WallpaperView: View {
    let theme: WallpaperTheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let unit = max(width, height)

            ZStack {
                LinearGradient(
                    colors: theme.baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(Array(theme.blobs.enumerated()), id: \.offset) { _, blob in
                    let diameter = blob.radius * unit * 2
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [blob.color.opacity(0.85), blob.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: diameter / 2
                            )
                        )
                        .frame(width: diameter, height: diameter)
                        .position(x: blob.x * width, y: blob.y * height)
                        .blur(radius: unit * 0.05)
                }

                // 暗角：压暗四周，让白色文字在任意壁纸上都能读。
                RadialGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    center: .center,
                    startRadius: unit * 0.22,
                    endRadius: unit * 0.78
                )
            }
            .frame(width: width, height: height)
        }
        .ignoresSafeArea()
    }
}
