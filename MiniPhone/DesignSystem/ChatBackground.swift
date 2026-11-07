import SwiftUI

/// 信息 App 的背景模式。
///
/// 主题渐变是墨绿底；流动动效在主题色上做缓慢漂移和呼吸；
/// 相册图片是从系统相册选一张，上面压暗膜保住气泡文字的对比度。
enum ChatBackgroundMode: String, CaseIterable, Identifiable {
    case theme
    case dynamic
    case photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theme: return "主题渐变"
        case .dynamic: return "流动动效"
        case .photo: return "相册图片"
        }
    }
}

/// 信息 App 的背景层：聊天页和会话列表共用一份设置。
///
/// 放在最底层 ZStack，调用方负责 `.ignoresSafeArea()`。
/// `SettingsStore` 是 `@Observable`，在这里读它的属性就能跟着设置变化重建。
struct ChatBackgroundView: View {
    let settings: SettingsStore

    var body: some View {
        switch settings.chatBackgroundMode {
        case .theme:
            Theme.backgroundGradient
        case .dynamic:
            AnimatedChatGradient()
        case .photo:
            photoLayer
        }
    }

    /// 图片铺满 + 上下压暗。文件读不到（被手动清了 Documents 之类）
    /// 就退回主题渐变，宁可回到默认也不能黑一块。
    private var photoLayer: some View {
        Group {
            if let image = WallpaperPhoto.load(fileName: settings.chatBackgroundPhoto) {
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.52),
                                    .black.opacity(0.26),
                                    .black.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            } else {
                Theme.backgroundGradient
            }
        }
    }
}

/// 缓慢漂移、呼吸的动效渐变。
///
/// 用时间驱动而不是 repeatForever 隐式动画：聊天页在流式回复、
/// 键盘起落时会频繁重建视图层，隐式动画经常被吞掉重启或跳帧，
/// 时间驱动的每帧重算不受这些影响。
private struct AnimatedChatGradient: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Theme.backgroundGradient
                .hueRotation(.degrees(sin(t / 7) * 16))
                .offset(x: sin(t / 9) * 46, y: cos(t / 11) * 34)
                .scaleEffect(1.3)
                .overlay {
                    LinearGradient(
                        colors: [
                            Theme.mint.opacity(0.14 * (sin(t / 5) + 1) / 2),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                }
        }
    }
}

/// 模式选择行的小色样，让三档在列表里一眼能分。
struct ChatBackgroundSwatch: View {
    let mode: ChatBackgroundMode
    var photo: UIImage?

    var body: some View {
        Group {
            switch mode {
            case .theme:
                Theme.backgroundGradient
            case .dynamic:
                // 静态帧画不出"动"，用偏移的色相示意它是会流的那个。
                Theme.backgroundGradient
                    .hueRotation(.degrees(24))
            case .photo:
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(Theme.separator)
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 0.5)
        }
    }
}
