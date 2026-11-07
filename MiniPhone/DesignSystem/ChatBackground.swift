import SwiftUI
import PhotosUI

/// 用户气泡的样式档。
///
/// 她点名绿色气泡要能自定义。玻璃档是气泡跟着背景走的透明款；
/// 彩色档换底色，文字自动配深浅（薄荷配深绿字，其余配白字）。
enum ChatBubbleStyle: String, CaseIterable, Identifiable {
    case mint
    case blue
    case pink
    case purple
    case glass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mint: return "薄荷"
        case .blue: return "蓝"
        case .pink: return "粉"
        case .purple: return "紫"
        case .glass: return "玻璃"
        }
    }

    /// 玻璃档返回 nil，气泡走 glassSurface。
    var fillColor: Color? {
        switch self {
        case .mint: return Theme.mint
        case .blue: return Color(red: 0.36, green: 0.72, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.56, blue: 0.72)
        case .purple: return Color(red: 0.72, green: 0.60, blue: 1.0)
        case .glass: return nil
        }
    }

    /// 底色上的字色。薄荷保持原来的深绿，其他亮色配白才不脏。
    var labelColor: Color {
        self == .mint ? Theme.deepGreen : .white
    }
}

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

/// 「聊天背景 + 气泡颜色」的设置节。
///
/// 外观页和「我的」页共用：她说换背景的入口藏在设置里找不到，
/// 要在「我的」里也能进。所以整节抽出来，两处引用同一份。
struct ChatBackgroundSection: View {
    let settings: SettingsStore

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoError: String?

    var body: some View {
        GroupedSection(
            "聊天背景",
            footer: "信息 App 的聊天页和会话列表共用一份。相册图上面会压一层暗膜，保证气泡文字看得清。"
        ) {
            modeRows
            RowDivider()
            photoRow

            if let message = photoError {
                Text(message)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.bottom, PhoneMetrics.Space.xs)
            }

            RowDivider()
            bubbleRows
        }
    }

    private var modeRows: some View {
        ForEach(Array(ChatBackgroundMode.allCases.enumerated()), id: \.offset) { index, mode in
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    settings.setChatBackground(mode)
                }
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    ChatBackgroundSwatch(
                        mode: mode,
                        photo: mode == .photo
                            ? WallpaperPhoto.load(fileName: settings.chatBackgroundPhoto)
                            : nil
                    )

                    Text(mode.displayName)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)

                    if settings.chatBackgroundMode == mode {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.tint)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if index < ChatBackgroundMode.allCases.count - 1 {
                RowDivider()
            }
        }
    }

    private var photoRow: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: PhoneMetrics.Space.s) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.tint)
                    .frame(width: 40, height: 40)

                Text(settings.chatBackgroundMode == .photo ? "换一张相册图" : "用相册里的图")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
    }

    private var bubbleRows: some View {
        ForEach(Array(ChatBubbleStyle.allCases.enumerated()), id: \.offset) { index, style in
            Button {
                settings.setChatBubble(style)
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    BubbleSwatch(style: style)

                    Text(style.displayName)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)

                    if settings.chatBubbleStyle == style {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.tint)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if index < ChatBubbleStyle.allCases.count - 1 {
                RowDivider()
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        photoError = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            photoError = "这张图读不出来，换一张试试。"
            return
        }

        do {
            let name = try WallpaperPhoto.save(image: image)
            let old = settings.chatBackgroundPhoto
            settings.setChatBackgroundPhoto(name)
            WallpaperPhoto.delete(fileName: old)
        } catch {
            photoError = (error as? LocalizedError)?.errorDescription ?? "存不下这张图。"
        }
    }
}

/// 气泡样式行的小样：一枚迷你气泡。
struct BubbleSwatch: View {
    let style: ChatBubbleStyle

    var body: some View {
        Group {
            if let fill = style.fillColor {
                Text("你好")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(style.labelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(fill))
            } else {
                Text("你好")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassSurface(cornerRadius: 12)
            }
        }
        .frame(width: 40, height: 40)
    }
}
