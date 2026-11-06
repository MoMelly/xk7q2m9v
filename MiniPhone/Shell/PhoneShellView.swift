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
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var noticeTask: Task<Void, Never>?

    /// 截图状态下要直开的那段会话。正常启动不会用到，也不写任何演示数据。
    @Query(sort: \Companion.createdAt, order: .forward) private var companions: [Companion]

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
        case "market", "feedInbox", "feedChat", "feedShare", "feedCard": destination = .scene(.feed)
        case "feed": destination = .scene(.feed)
        case "feedProfile": destination = .scene(.feed)
        case "letters": destination = .scene(.letters)
        case "chatDetail", "chatMine", "chatEditor": destination = .chat
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
                    wallpaper: settings.wallpaperTheme,
                    onUnlock: unlock,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
            } else {
                HomeScreenView(
                    wallpaper: settings.wallpaperTheme,
                    onOpen: open,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
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
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: PhoneMetrics.appLaunchStartScale).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
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
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: openedApp)
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
            seedPreviewContentIfNeeded()
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

    // MARK: - App 层

    @ViewBuilder
    private func appLayer(_ app: PhoneApp) -> some View {
        switch app.destination {
        case .chat:
            if Self.previewState == "chatDetail", let character = companions.first {
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

    // MARK: - 截图用的演示数据

    /// 只在带 `-previewState` 启动时写。正常启动读不到这个键，一条都不会插。
    /// 聊天详情和我的主页没有预置内容就是空态，截图看不出布局对不对。
    @MainActor
    private func seedPreviewContentIfNeeded() {
        switch Self.previewState {
        case "chatDetail":
            guard companions.isEmpty else { return }
            let character = Companion(
                name: "小满",
                persona: "住在隔壁、话不多但记性很好的女生，说话短，不爱用感叹号。",
                greeting: "回来啦？今天楼下那家关得早。"
            )
            character.signature = "慢一点也没关系"
            context.insert(character)

            let lines: [(ChatMessage.Role, String)] = [
                (.assistant, "回来啦？今天楼下那家关得早。"),
                (.user, "啊，那我明天早点去。"),
                (.assistant, "嗯，我给你留了张便签在门上。")
            ]
            for (index, line) in lines.enumerated() {
                let message = StoredMessage(
                    characterUID: character.uid,
                    role: line.0,
                    text: line.1,
                    createdAt: Date().addingTimeInterval(Double(index) * 60 - 180)
                )
                message.character = character
                context.insert(message)
            }
            try? context.save()

        case "feedProfile":
            guard !world.state.feed.contains(where: { $0.authorName == "我" }) else { return }
            world.publishNote(
                title: "今天把窗台收拾了一下",
                body: "擦完灰才发现那盆薄荷偷偷长高了一截。",
                tag: "日常"
            )
            world.publishNote(
                title: "晚自习后的操场",
                body: "灯只亮了一半，风比白天凉很多。",
                tag: "傍晚"
            )
            world.publishNote(
                title: "给自己留的一小时",
                body: "什么都不做，坐着发呆也算数。",
                tag: "记录"
            )

        case "market":
            world.seedPreviewShop()

        case "feedInbox", "feedChat", "feedShare", "feedCard":
            seedPreviewInbox()

        default:
            break
        }
    }

    /// 私信/转帖的演示数据：角色、两类来件、活动索引、开场白消息一次配齐。
    /// 只在带 -previewState 时写，正常启动一行都不碰。
    @MainActor
    private func seedPreviewInbox() {
        guard world.state.feedInbox.isEmpty else { return }

        let character: Companion
        if let existing = companions.first(where: { $0.name == "小满" }) {
            character = existing
        } else {
            let fresh = Companion(
                name: "小满",
                persona: "住在隔壁、话不多但记性很好的女生，说话短，不爱用感叹号。",
                greeting: ""
            )
            fresh.signature = "慢一点也没关系"
            context.insert(fresh)
            character = fresh
        }

        let share = FeedInboxItem(
            id: UUID(),
            kind: .postShare,
            companionUID: character.uid.uuidString,
            companionName: character.name,
            noteID: nil,
            noteTitle: "晚自习后的操场",
            noteBody: "灯只亮了一半，风比白天凉很多。你上次说想再去走走。",
            noteTag: "傍晚",
            coverSeed: 264,
            message: "看到这篇就想起你，周末要不要一起去？",
            createdAt: Date().addingTimeInterval(-3_600),
            isRead: true,
            threadID: UUID()
        )
        let direct = FeedInboxItem(
            id: UUID(),
            kind: .directMessage,
            companionUID: character.uid.uuidString,
            companionName: character.name,
            noteID: nil,
            noteTitle: "",
            noteBody: "",
            noteTag: "",
            coverSeed: 0,
            message: "刚路过楼下那家，给你带了杯热的。",
            createdAt: Date().addingTimeInterval(-600),
            isRead: false,
            threadID: UUID()
        )
        world.deliverFeedInbox(share)
        world.deliverFeedInbox(direct)

        for item in [share, direct] {
            if item.kind == .postShare {
                let sharedPost = FeedPostCardPayload(
                    noteID: item.noteID?.uuidString ?? "",
                    title: item.noteTitle,
                    body: item.noteBody,
                    tag: item.noteTag,
                    coverSeed: item.coverSeed
                )
                let cardLine = StoredMessage(
                    characterUID: character.uid,
                    role: .assistant,
                    text: sharedPost.encoded(),
                    channel: .feedShare,
                    threadID: item.threadID,
                    createdAt: item.createdAt.addingTimeInterval(-1)
                )
                cardLine.character = character
                context.insert(cardLine)
            }

            let message = StoredMessage(
                characterUID: character.uid,
                role: .assistant,
                text: item.message,
                channel: item.kind == .postShare ? .feedShare : .feedDM,
                threadID: item.threadID,
                createdAt: item.createdAt
            )
            message.character = character
            context.insert(message)
        }
        // 演示「我分享了一篇帖子」：卡片落在私信 thread 里，不是转帖通道。
        let myPost = FeedPostCardPayload(
            noteID: UUID().uuidString,
            title: "给自己留的一小时",
            body: "什么都不做，坐着发呆也算数。",
            tag: "记录",
            coverSeed: 264
        )
        let cardMessage = StoredMessage(
            characterUID: character.uid,
            role: .user,
            text: myPost.encoded(),
            channel: .feedDM,
            threadID: direct.threadID,
            createdAt: Date().addingTimeInterval(-240)
        )
        cardMessage.character = character
        context.insert(cardMessage)
        try? context.save()
    }

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
            openedApp = app
            openedAt = Date()
        case .placeholder:
            showToast("「\(app.name)」还没做")
        }
    }

    private func closeApp() {
        if let app = openedApp, let start = openedAt {
            world.noteUsage(appName: app.name, seconds: Date().timeIntervalSince(start))
        }
        openedApp = nil
        openedAt = nil
    }
}
