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
    /// 控制中心从右上角拉下来。
    @State private var showControlCenter = PhoneShellView.previewControlCenter
    private let controlCenter = ControlCenterStore.shared
    /// 播放器是单例，外壳只读不持有——退出 App 页面也接着放。
    private let player = PlayerService.shared

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

    /// 截图：直接落到控制中心展开的样子。
    private static var previewControlCenter: Bool {
        previewState == "controlCenter"
    }

    /// 这些状态要直接进某个角色的聊天页，跳过会话列表。
    /// 单列一份是因为后面还有弹层要判断同一组名字，散在多处容易漏。
    private static var opensChatDirectly: Bool {
        switch previewState {
        case "chatDetail", "chatStickers", "chatPhoto", "chatDynamic", "chatGlass", "charDetail", "board",
             "statePanel", "anonBox", "worldEntries", "chatGroup", "groupDetail", "groupMemory",
             "call", "chatTogether", "redPacket":
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
        case "settings", "theme", "memoryLibrary": destination = .settings
        case "calendar": destination = .scene(.calendar)
        case "notes": destination = .scene(.notes)
        case "music", "musicBall", "musicLyrics": destination = .scene(.music)
        case "market", "feedInbox", "feedChat", "feedShare", "feedCard", "feedLive": destination = .scene(.feed)
        case "feed": destination = .scene(.feed)
        case "feedProfile": destination = .scene(.feed)
        case "letters": destination = .scene(.letters)
        case "reading": destination = .scene(.reading)
        case "phonePeek": destination = .scene(.phonePeek)
        case "couple": destination = .scene(.couple)
        case "storyGame", "storyPlay", "storyEnd": destination = .scene(.storyGame)
        case "chatDetail", "chatMine", "chatCalls", "chatEditor", "chatStickers", "chatPhoto",
             "chatDynamic", "chatGlass", "avatarPicker", "chatGroup", "groupDetail", "groupMemory",
             "charDetail", "board", "statePanel", "anonBox", "worldEntries",
             "call", "chatTogether", "redPacket": destination = .chat
        case "chatNight": destination = .chat
        default: destination = nil
        }
        guard let destination else { return nil }
        // Dock 里的 App 不在桌面清单里了，找的时候两份合起来找。
        return (AppCatalog.home + AppCatalog.dock).first { $0.destination == destination }
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
                    videoWallpaperEnabled: settings.videoWallpaperEnabled && !settings.discreetMode,
                    passcode: settings.passcode,
                    hidesWidgets: settings.discreetMode
                )
                .transition(.opacity)
            } else {
                HomeScreenView(
                    selection: settings.homeSelection,
                    world: world,
                    onOpen: open,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled && !settings.discreetMode,
                    musicPlaying: player.isPlaying,
                    hidesWidgets: settings.discreetMode
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

            // 悬浮球：真的有歌在放才出现，App 页之上、提示之下。
            // 歌词页不套系统 sheet——手机壳里再弹一个系统面板，拟真就破了。
            if player.track != nil, !isLocked {
                MiniPlayerOverlay(player: player)
                    .zIndex(2.5)
            }

            if let toastText {
                toast(toastText)
                    .zIndex(3)
            }

            // 勿扰开着就不弹横幅：开关要是只改个颜色，那它就只是个装饰。
            if !world.pendingNotices.isEmpty, !controlCenter.silent {
                VStack(spacing: 0) {
                    NotificationStack(notices: notices, onDismiss: dismissNotice)
                        .padding(.top, PhoneMetrics.notificationTopInset)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(4)
            }

            // 亮度：整屏盖一层黑，盖在所有东西之上但不吃点击。
            // 控制中心本身要在它上面，否则拉下来看不清滑杆。
            if controlCenter.brightness < 0.95 {
                Color.black
                    .opacity((1 - controlCenter.brightness) * 0.62)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(4.5)
            }

            if showControlCenter {
                // 遮罩压到 0.3：0.16 的时候底下那排图标名跟面板底边挤在一起，
                // 分不清是面板里的字还是桌面上的字。
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture { closeControlCenter() }
                    .zIndex(5)

                VStack(spacing: 0) {
                    ControlCenterPanel(
                        world: world,
                        settings: settings,
                        onClose: closeControlCenter,
                        onOpenSettings: {
                            closeControlCenter()
                            if let app = (AppCatalog.home + AppCatalog.dock)
                                .first(where: { $0.destination == .settings }) {
                                open(app)
                            }
                        }
                    )
                    .padding(.top, 8)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(6)
            }
        }
        // 右上角往下拉。只在桌面上留这条热区：进了 App 之后顶栏右上是它自己的按钮，
        // 盖一条看不见的拖拽带上去，点「⋯」会变成拉控制中心。
        .overlay(alignment: .topTrailing) {
            if openedApp == nil, !showControlCenter {
                Color.clear
                    .frame(width: 132, height: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onEnded { value in
                                guard value.translation.height > 22 else { return }
                                Haptics.tap()
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                    showControlCenter = true
                                }
                            }
                    )
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
            // 主屏和锁屏只有一块地方，挑人的规则跟「TA 的手机」默认打开谁一致：
            // 最近说过话的那个。小助手不算——它不是谈恋爱的人；群也不算，
            // 小组件上写一个群名，看起来像系统在提醒你有个群。
            let primary = companions
                .filter { !$0.isFeedOnly && !$0.isGroup && $0.name != DefaultAssistant.name }
                .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
                .first?.name ?? ""
            if !primary.isEmpty { world.primaryName = primary }
            // 上次设的音量在启动时落到播放器上：它存在控制中心那边，播放器是无状态的。
            player.volume = controlCenter.volume
            world.ensureToday(wakeHour: 7, sleepHour: 23)
            world.seedSceneContentIfNeeded()
            UserProfileBook.ensureDefault(in: context)
            DefaultAssistant.ensure(in: context)
            BuiltInStickers.ensure(in: context)
            StickerLibrary.shared.reload(context: context)
            retirePortraitAvatars()

            // 只有正常启动才种。截图流水线自己摆数据，
            // 两条种子叠在一起，画面上会多出一堆没预期的会话。
            if UserDefaults.standard.string(forKey: "previewState") == nil {
                FirstRunSeed.runIfNeeded(context: context, world: world, companions: companions)
            }

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

    // MARK: - 控制中心

    private func closeControlCenter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showControlCenter = false
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
            // 西瓜皮现在只在 Dock 里，桌面那张表查不到它。
            guard let app = (AppCatalog.home + AppCatalog.dock)
                .first(where: { $0.destination == destination }) else {
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
            // 截图直开时挑「最近说过话的那个人」，和主屏组件、查手机用的是
            // 同一条规则。不能取列表第一个：内置小助手最先建、sortIndex 又靠前，
            // 取 first 会让所有预览（状态面板、提问箱、详情）都落到它头上，
            // 预置在世界状态里的数据全挂在那个人身上，一幅都对不上。
            if Self.opensChatDirectly,
               let character = companions.max(by: {
                   ($0.lastMessageAt ?? .distantPast) < ($1.lastMessageAt ?? .distantPast)
               }) {
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
