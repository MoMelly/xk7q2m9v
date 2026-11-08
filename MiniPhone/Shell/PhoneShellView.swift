import SwiftUI
import SwiftData

/// 外壳总容器。
///
/// 三个状态：锁屏 → 桌面 → 打开某个 App。用状态机而不是 NavigationStack，
/// 因为真机是没有导航栏的，页面之间的关系是「盖上去」而不是「推过去」。
struct PhoneShellView: View {
    @Bindable var settings: SettingsStore
    @Environment(WorldStore.self) private var world
    @Environment(\.modelContext) private var context

    @State private var isLocked: Bool = PhoneShellView.previewLocked
    @State private var openedApp: PhoneApp? = PhoneShellView.previewApp
    @State private var openedAt: Date?
    /// 打开动效的进度：0 = 还是那颗图标的大小，1 = 铺满全屏。
    @State private var appOpenProgress: CGFloat = 1
    /// 被点的那颗图标的全局位置，裁剪就是从这里长出来的。
    @State private var appLaunchAnchor: CGRect = .zero
    /// 主屏上报的图标位置，按 App id 索引。
    @State private var iconFrames: [String: CGRect] = [:]
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var noticeTask: Task<Void, Never>?

    /// 截图状态下要直开的那段会话。正常启动不会用到，也不写任何演示数据。
    @Query(sort: \Companion.createdAt, order: .forward) private var companions: [Companion]
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    // MARK: - 截图用的启动状态

    /// 启动参数 `-previewState <名字>` 让外壳直接落到指定状态。
    /// `chatDetail` 和 `feedProfile` 是两级页面，靠桌面图标点不到，所以各留一个状态；
    /// 截图流水线靠这些状态跳过多层手势。
    private static var previewState: String {
        UserDefaults.standard.string(forKey: "previewState") ?? "lock"
    }

    private static var previewLocked: Bool {
        previewState == "lock"
    }

    /// 这些状态要直接进某个角色的聊天页，跳过会话列表。
    /// 单列一份是因为后面还有弹层要判断同一组名字，散在多处容易漏。
    private static var opensChatDirectly: Bool {
        switch previewState {
        case "chatDetail", "chatStickers", "chatPhoto", "chatDynamic", "chatGlass", "charDetail", "call":
            return true
        default:
            return false
        }
    }

    private static var previewApp: PhoneApp? {
        let destination: PhoneApp.Destination?
        switch previewState {
        case "chat": destination = .chat
        case "moments": destination = .moments
        case "settings", "theme": destination = .settings
        case "calendar": destination = .scene(.calendar)
        case "notes": destination = .scene(.notes)
        case "music": destination = .scene(.music)
        case "health": destination = .scene(.health)
        case "market", "feedInbox", "feedChat", "feedShare", "feedCard", "feedLive": destination = .scene(.feed)
        case "feed": destination = .scene(.feed)
        case "feedProfile": destination = .scene(.feed)
        case "letters": destination = .scene(.letters)
        case "reading": destination = .scene(.reading)
        case "phonePeek": destination = .scene(.phonePeek)
        case "storyGame": destination = .scene(.storyGame)
        case "chatDetail", "chatMine", "chatEditor", "chatStickers", "chatPhoto", "chatDynamic", "chatGlass", "avatarPicker",
             "charDetail", "call": destination = .chat
        case "chatNight": destination = .chat
        default: destination = nil
        }
        guard let destination else { return nil }
        return AppCatalog.home.first { $0.destination == destination }
    }

    /// 夜间截图：状态名带 Night 后缀就切到夜间。
    /// 只改内存值不落盘，别让截图流水线把用户设置改成夜间。
    private static var previewNight: Bool {
        previewState.hasSuffix("Night")
    }

    /// 图标样式截图：`homeVector` / `homeDark` 各对应一种矢量画法，
    /// 同样只改内存，不动用户已经存下来的设置。
    private static func applyPreviewTheme() {
        switch previewState {
        case "homeVector":
            ThemeStore.shared.iconStyleRaw = IconStyle.light.rawValue
        case "homeDark":
            ThemeStore.shared.iconStyleRaw = IconStyle.dark.rawValue
        default:
            break
        }
    }

    var body: some View {
        ZStack {
            if isLocked {
                LockScreenView(
                    selection: settings.lockSelection,
                    onUnlock: unlock,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
            } else {
                HomeScreenView(
                    selection: settings.homeSelection,
                    world: world,
                    onOpen: open,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
                .onPreferenceChange(IconFramePreferenceKey.self) { frames in
                    iconFrames = frames
                }
            }

            // 夜间：桌面和锁屏这一层压黑。App 页自己走深色 token，
            // 再蒙一遍会把里面的白色卡片也压灰，所以只盖壁纸这一层。
            if ThemeStore.shared.isNight {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let app = openedApp {
                appLayer(app)
                    // 遮罩要铺到整屏：App 页的背景自己会往安全区外延伸，
                    // 遮罩只按安全区算的话，上下会各裁掉一条、露出壁纸。
                    .mask { launchMask.ignoresSafeArea() }
                    .zIndex(2)
            }

            if let toastText {
                toast(toastText)
                    .zIndex(3)
            }

            if !world.pendingNotices.isEmpty {
                VStack(spacing: 0) {
                    NotificationStack(notices: notices, onDismiss: dismissNotice)
                        .padding(.top, PhoneMetrics.notificationTopInset)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(4)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isLocked)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: world.pendingNotices)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { @MainActor in
            if Self.previewNight {
                ThemeStore.shared.appearanceRaw = AppearanceMode.night.rawValue
            }
            Self.applyPreviewTheme()
            world.ensureToday(wakeHour: 7, sleepHour: 23)
            world.seedSceneContentIfNeeded()
            UserProfileBook.ensureDefault(in: context)
            DefaultAssistant.ensure(in: context)
            BuiltInStickers.ensure(in: context)
            StickerLibrary.shared.reload(context: context)
            retirePortraitAvatars()
            PreviewSeeder(
                state: Self.previewState,
                companions: companions,
                context: context,
                world: world
            ).run()
        }
        .onChange(of: world.pendingNotices) { _, pages in
            guard !pages.isEmpty else { return }
            scheduleNoticeDismiss()
        }
    }

    // MARK: - 通知横幅

    /// 把刷新页面映射回桌面图标，横幅上用的就是用户认得的那个 App 图标。
    private var notices: [NotificationStack.Notice] {
        world.pendingNotices.compactMap { page -> NotificationStack.Notice? in
            let destination: PhoneApp.Destination
            switch page {
            // 市集已经并入西瓜皮，横幅用西瓜皮的图标。
            case .shop: destination = .scene(.feed)
            case .feed: destination = .scene(.feed)
            }
            guard let app = AppCatalog.home.first(where: { $0.destination == destination }) else {
                return nil
            }
            return NotificationStack.Notice(
                symbol: app.symbol,
                colors: app.colors,
                title: app.name,
                message: page.notice.split(separator: "·").last.map { String($0).trimmingCharacters(in: .whitespaces) }
                    ?? page.notice
            )
        }
    }

    private func scheduleNoticeDismiss() {
        noticeTask?.cancel()
        noticeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            dismissNotice()
        }
    }

    private func dismissNotice() {
        noticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) {
            world.consumeNotice()
        }
    }

    // MARK: - 打开动效

    /// 打开 / 关闭时的裁剪：一块圆角矩形从被点的图标长到全屏。
    ///
    /// 不用整层缩放：缩放时四边会先露出主屏，看上去就是「上边下边先流出一道痕」。
    /// 裁剪则始终有一块完整画面在框内，边缘不会漏。
    /// 圆角从图标的 22% 收到 0，和真机 App 展开的观感一致。
    private var launchMask: some View {
        GeometryReader { proxy in
            let t = min(max(appOpenProgress, 0), 1)
            let origin = proxy.frame(in: .global).origin
            let start = CGRect(
                x: appLaunchAnchor.minX - origin.x,
                y: appLaunchAnchor.minY - origin.y,
                width: appLaunchAnchor.width,
                height: appLaunchAnchor.height
            )
            let full = CGRect(origin: .zero, size: proxy.size)
            let rect = CGRect(
                x: start.minX + (full.minX - start.minX) * t,
                y: start.minY + (full.minY - start.minY) * t,
                width: start.width + (full.width - start.width) * t,
                height: start.height + (full.height - start.height) * t
            )

            RoundedRectangle(
                cornerRadius: PhoneMetrics.iconCornerRadius * (1 - t),
                style: .continuous
            )
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .position(x: rect.midX, y: rect.midY)
        }
    }

    // MARK: - App 层

    @ViewBuilder
    private func appLayer(_ app: PhoneApp) -> some View {
        switch app.destination {
        case .chat:
            if Self.opensChatDirectly, let character = companions.first {
                ChatView(character: character, settings: settings, onExit: closeApp)
            } else {
                ConversationListView(settings: settings, onExit: closeApp)
            }
        case .moments:
            MomentsView(settings: settings, onExit: closeApp)
        case .settings:
            SettingsView(settings: settings, onExit: closeApp)
        case .scene(let kind):
            ScenePage(kind: kind, settings: settings, world: world, onExit: closeApp)
        case .placeholder:
            // 占位图标不会走进来，open(_:) 里已经拦掉了。
            EmptyView()
        }
    }

    // MARK: - 数据迁移

    /// 早期版本内置过一组真人照片头像，后来整组撤掉了。
    ///
    /// 老库里还挂着 `avatar_p` 这种键，图已经不随包了，读出来是空，
    /// 头像会退成一块渐变圆加首字。启动时扫一遍换成现有的随机图，
    /// 只在真的存在这种键时才写库，正常启动不碰。
    @MainActor
    private func retirePortraitAvatars() {
        var touched = false

        for character in companions where AvatarPhoto.isRetired(key: character.avatarImageKey) {
            character.avatarImageKey = AvatarPhoto.randomKey()
            touched = true
        }
        for profile in profiles where AvatarPhoto.isRetired(key: profile.avatarImageKey) {
            profile.avatarImageKey = AvatarPhoto.randomKey()
            touched = true
        }

        if touched {
            try? context.save()
        }
    }

    // MARK: - 截图用的演示数据（见 PreviewSeed.swift）

    // MARK: - Toast

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .glassSurface(cornerRadius: 22)

            Spacer(minLength: 0).frame(height: 130)
        }
        .transition(.opacity.combined(with: .offset(y: 14)))
    }

    @MainActor
    private func showToast(_ text: String) {
        toastTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            toastText = text
        }

        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toastText = nil
            }
        }
    }

    // MARK: - 状态切换

    private func unlock() {
        isLocked = false
    }

    private func open(_ app: PhoneApp) {
        switch app.destination {
        case .chat, .moments, .settings, .scene:
            // 先把画面挂上、再让裁剪从小长到大。
            // 反过来做（先动画再建视图）动画会等视图建完，就是那下卡顿。
            appLaunchAnchor = iconFrames[app.id] ?? .zero
            appOpenProgress = 0
            openedApp = app
            openedAt = Date()

            guard !appLaunchAnchor.isEmpty else {
                // 没拿到图标位置（比如预览直开）就直接铺满，不做假的放大。
                appOpenProgress = 1
                return
            }

            // 下一帧再动：这一帧先把 App 的内容建出来，
            // 建完的那一帧裁剪还停在图标大小，看不出停顿。
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    appOpenProgress = 1
                }
            }
        case .placeholder:
            showToast("「\(app.name)」还没做")
        }
    }

    private func closeApp() {
        if let app = openedApp, let start = openedAt {
            world.noteUsage(appName: app.name, seconds: Date().timeIntervalSince(start))
        }
        guard !appLaunchAnchor.isEmpty else {
            openedApp = nil
            openedAt = nil
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            appOpenProgress = 0
        } completion: {
            openedApp = nil
            openedAt = nil
            appLaunchAnchor = .zero
            appOpenProgress = 1
        }
    }
}
