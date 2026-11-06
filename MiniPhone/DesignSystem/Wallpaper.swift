import SwiftUI
import UIKit

/// 内置壁纸。
///
/// 旧版四套都是深底 + 四周压暗，叠上白色状态栏和图标文字会显脏。
/// 现在四套全换成浅色：第一套是随包的云朵图，另外三套仍由代码画，
/// 图片读不到时自动退回渐变，不会露黑屏。
/// case 名字沿用旧值，是为了让已经存进 UserDefaults 的主题不用迁移也能变干净。
enum WallpaperTheme: String, CaseIterable, Identifiable {
    case midnight
    case forest
    case ember
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "云朵"
        case .forest: return "薄荷"
        case .ember: return "奶油"
        case .graphite: return "雾蓝"
        }
    }

    /// 只有第一套用位图。文件名不带扩展名，`Bundle.main.url` 自己拼 .jpg。
    var imageName: String? {
        self == .midnight ? "daydream" : nil
    }

    var image: Image? {
        guard let imageName,
              let url = Bundle.main.url(forResource: imageName, withExtension: "jpg"),
              let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
    }

    /// 基底渐变，左上到右下。位图主题用这组色当兜底。
    var baseColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.98, green: 0.88, blue: 0.93),
                Color(red: 0.80, green: 0.90, blue: 0.98)
            ]
        case .forest:
            return [
                Color(red: 0.92, green: 0.98, blue: 0.94),
                Color(red: 0.80, green: 0.94, blue: 0.90)
            ]
        case .ember:
            return [
                Color(red: 1.00, green: 0.96, blue: 0.88),
                Color(red: 0.98, green: 0.88, blue: 0.82)
            ]
        case .graphite:
            return [
                Color(red: 0.94, green: 0.96, blue: 1.00),
                Color(red: 0.82, green: 0.88, blue: 0.96)
            ]
        }
    }

    /// 叠在基底上的光斑。透明度压得很低，浅底上只留一点纵深。
    var blobs: [WallpaperBlob] {
        switch self {
        case .midnight:
            return [
                WallpaperBlob(x: 0.18, y: 0.16, radius: 0.46, color: Color(red: 0.98, green: 0.78, blue: 0.88)),
                WallpaperBlob(x: 0.82, y: 0.62, radius: 0.40, color: Color(red: 0.76, green: 0.88, blue: 0.98))
            ]
        case .forest:
            return [
                WallpaperBlob(x: 0.22, y: 0.16, radius: 0.48, color: Color(red: 0.72, green: 0.92, blue: 0.82)),
                WallpaperBlob(x: 0.82, y: 0.72, radius: 0.42, color: Color(red: 0.86, green: 0.96, blue: 0.88))
            ]
        case .ember:
            return [
                WallpaperBlob(x: 0.76, y: 0.18, radius: 0.44, color: Color(red: 0.99, green: 0.86, blue: 0.72)),
                WallpaperBlob(x: 0.20, y: 0.72, radius: 0.40, color: Color(red: 0.99, green: 0.93, blue: 0.84))
            ]
        case .graphite:
            return [
                WallpaperBlob(x: 0.30, y: 0.22, radius: 0.50, color: Color(red: 0.84, green: 0.90, blue: 0.99)),
                WallpaperBlob(x: 0.78, y: 0.70, radius: 0.44, color: Color(red: 0.92, green: 0.94, blue: 0.99))
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
                if let image = theme.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                } else {
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
                                    colors: [blob.color.opacity(0.45), blob.color.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: diameter / 2
                                )
                            )
                            .frame(width: diameter, height: diameter)
                            .position(x: blob.x * width, y: blob.y * height)
                            .blur(radius: unit * 0.04)
                    }
                }

                // 只压顶部一小段：状态栏和锁屏时间仍是白字，浅底上要有一点暗才读得出。
                LinearGradient(
                    colors: [.black.opacity(0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.22)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: width, height: height)
        }
        .ignoresSafeArea()
    }
}

/// 锁屏与桌面共用的背景层。
///
/// 代码壁纸始终打底：视频没导入、解码失败或正在后台时不会露出黑屏。
/// 视频层只负责循环播放，暂停逻辑在 VideoWallpaperView 里按 scenePhase 处理。
struct WallpaperBackdrop: View {
    let theme: WallpaperTheme
    var videoEnabled: Bool = false

    var body: some View {
        ZStack {
            WallpaperView(theme: theme)

            if videoEnabled, VideoWallpaperStore.exists {
                VideoWallpaperView(url: VideoWallpaperStore.fileURL)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}
