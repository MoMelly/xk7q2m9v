import SwiftUI
import SwiftData

/// 西瓜皮。
///
/// 底部五格对称：首页 / 市集 / 发布 / 消息 / 我的，发布固定在正中间。
/// 购物不再单独占一个桌面图标，商品流整块搬进「市集」。
/// 右上角刷新按当前 tab 走 .feed 或 .shop，两个页面共用一条反馈条。
struct FeedScene: View {
    let world: WorldStore
    let settings: SettingsStore
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var companions: [Companion]

    /// 截图状态直接落到对应 tab，省掉多层点击；正常启动都是首页。
    @State private var phoneTab: PhoneTab = {
        switch UserDefaults.standard.string(forKey: "previewState") {
        case "feedProfile": return .mine
        case "market": return .market
        case "feedInbox", "feedChat", "feedShare", "feedCard": return .messages
        default: return .home
        }
    }()
    @State private var feedTab: FeedTab =
        UserDefaults.standard.string(forKey: "previewState") == "feedLive" ? .live : .discover
    @State private var isComposing = false
    /// 直接取单例而不是存进 @State：@State 的初始化不在 body 里，
    /// 拿 @MainActor 的 shared 会踩隔离检查。在 body 里读一次，观察照样成立。
    private var refresher: RefreshService { .shared }
    private var proactive: ProactiveFeedService { .shared }
    @State private var statusText: String?
    @State private var statusTask: Task<Void, Never>?
    /// 分享完要打开的那段私聊。tick 单独计数，连着分享到同一段也会再触发一次。
    @State private var shareThreadID: UUID?
    @State private var shareTick = 0

    private var currentPage: RefreshPage {
        phoneTab == .market ? .shop : .feed
    }

    enum PhoneTab: String, CaseIterable, Identifiable {
        case home = "首页"
        case market = "市集"
        case messages = "消息"
        case mine = "我的"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .home: return "house"
            case .market: return "bag"
            case .messages: return "bubble.left.and.bubble.right"
            case .mine: return "person"
            }
        }
    }

    enum FeedTab: String, CaseIterable, Identifiable {
        case discover = "发现"
        case following = "关注"
        case live = "直播"

        var id: String { rawValue }
    }

    private var notes: [FeedNote] {
        let all = world.state.feed.sorted { $0.postedAt > $1.postedAt }
        switch feedTab {
        case .discover: return all
        case .following: return all.filter { $0.authorUID != nil }
        case .live: return []
        }
    }

    var body: some View {
        AppScreen(
            title: phoneTab == .mine ? "" : "西瓜皮",
            surface: .light,
            onClose: onClose,
            trailingSymbol: "arrow.clockwise",
            trailingAction: refreshCurrent,
            transparentBar: phoneTab == .mine
        ) {
            VStack(spacing: 0) {
                if phoneTab == .home {
                    searchBar
                    feedTabs
                }

                if let statusText {
                    RefreshStatusStrip(text: statusText, isLoading: refresher.isRefreshing(currentPage))
                }

                switch phoneTab {
                case .home:
                    content
                case .market:
                    MarketView(world: world)
                case .messages:
                    FeedInboxPage(
                        world: world,
                        settings: settings,
                        openThreadID: shareThreadID,
                        openTick: shareTick
                    )
                case .mine:
                    FeedProfilePage(
                        world: world,
                        settings: settings,
                        onCompose: { isComposing = true }
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bottomBar
            }
        }
        .sheet(isPresented: $isComposing) {
            NoteComposer(world: world, onClose: {
                isComposing = false
                phoneTab = .mine
            })
        }
        .task { @MainActor in
            // 角色自己决定要不要在西瓜皮上找你说句话，不需要你点任何按钮。
            // 服务内部按人限流，没填 Key 会直接返回。
            //
            // 挑最近说过话的那个，不是查询顺序里的第一个：原来固定取 first，
            // 有多个角色时只有那一个人会来私信，其他人永远沉默。
            let pool = companions.filter { !$0.isFeedOnly }
            guard let character = pool.max(by: {
                ($0.lastMessageAt ?? .distantPast) < ($1.lastMessageAt ?? .distantPast)
            }) else { return }
            guard let item = await proactive.deliverIfDue(
                character: character,
                settings: settings
            ) else { return }

            // 转帖先把帖子卡片放进消息流，附言排在它后面。
            if item.kind == .postShare {
                let card = FeedPostCardPayload(
                    noteID: item.noteID?.uuidString ?? "",
                    title: item.noteTitle,
                    body: item.noteBody,
                    tag: item.noteTag,
                    coverSeed: item.coverSeed
                )
                let cardLine = StoredMessage(
                    characterUID: character.uid,
                    role: .assistant,
                    text: card.encoded(),
                    channel: .feedShare,
                    threadID: item.threadID,
                    createdAt: item.createdAt.addingTimeInterval(-1)
                )
                cardLine.character = character
                context.insert(cardLine)
            }

            // 开场白补进同一份角色记忆，界面按 channel 过滤。
            let opening = StoredMessage(
                characterUID: character.uid,
                role: .assistant,
                text: item.message,
                channel: item.kind == .postShare ? .feedShare : .feedDM,
                threadID: item.threadID
            )
            opening.character = character
            context.insert(opening)
            try? context.save()
        }
    }

    // MARK: - 顶部

    private var searchBar: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
            Text("搜点什么")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Spacer(minLength: 0)

            if refresher.isRefreshing(.feed) {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .padding(.horizontal, PhoneMetrics.Space.s)
        .frame(height: 34)
        .background(
            Capsule().fill(AppSurface.light.rowSurface)
        )
        .overlay(
            Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.5)
        )
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.xs)
    }

    private var feedTabs: some View {
        HStack(spacing: PhoneMetrics.Space.l) {
            ForEach(FeedTab.allCases) { item in
                Button {
                    feedTab = item
                } label: {
                    VStack(spacing: 5) {
                        Text(item.rawValue)
                            .font(.system(
                                size: PhoneMetrics.FontSize.sub,
                                weight: feedTab == item ? .semibold : .regular
                            ))
                            .foregroundStyle(
                                feedTab == item ? AppSurface.light.label : AppSurface.light.secondaryLabel
                            )

                        Capsule()
                            .fill(feedTab == item ? Theme.brand : .clear)
                            .frame(width: 16, height: 2)
                    }
                    .padding(.top, PhoneMetrics.Space.s)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.xs)
    }

    // MARK: - 瀑布流
    @ViewBuilder
    private var content: some View {
        if feedTab == .live {
            LiveListPage(companions: companions.filter { !$0.isFeedOnly }, settings: settings)
        } else if notes.isEmpty {
            emptyState
        } else {
            GeometryReader { proxy in
                let width = (proxy.size.width - PhoneMetrics.Space.m * 2 - PhoneMetrics.Space.xs) / 2
                let columns = FeedWaterfall.split(notes, into: 2, width: width)

                ScrollView {
                    HStack(alignment: .top, spacing: PhoneMetrics.Space.xs) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            LazyVStack(spacing: PhoneMetrics.Space.xs) {
                                ForEach(column) { note in
                                    NavigationLink {
                                        FeedDetailPage(
                                            note: note,
                                            world: world,
                                            settings: settings,
                                            onShared: handleShared
                                        )
                                    } label: {
                                        FeedCard(note: note, width: width)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.top, PhoneMetrics.Space.xxs)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "book.closed")
                .font(.system(size: 26))
            Text(feedTab == .following ? "角色还没发过笔记" : "还没刷出笔记")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("右上角刷新一下，或者多聊几句。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(PhoneTab.allCases) { item in
                // 加号插在第三格，两边各两格才对称。
                if item == .messages {
                    composeButton
                }

                Button {
                    phoneTab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: phoneTab == item ? "\(item.symbol).fill" : item.symbol)
                            .font(.system(size: 18, weight: .regular))
                        Text(item.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(
                        phoneTab == item ? AppSurface.light.label : AppSurface.light.secondaryLabel
                    )
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, PhoneMetrics.Space.xs)
        .padding(.bottom, PhoneMetrics.Space.xs)
        .background(AppSurface.light.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppSurface.light.separator.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    /// 发帖的唯一入口。红色胶囊是这一页唯一的实心红。
    private var composeButton: some View {
        Button {
            isComposing = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 30)
                .background(Capsule().fill(Theme.brand))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    /// 分享完直接切到消息 tab 并展开那段私聊，卡片就在里面。
    private func handleShared(_ threadID: UUID) {
        shareThreadID = threadID
        shareTick += 1
        phoneTab = .messages
    }

    // MARK: - 刷新

    private func refreshCurrent() {
        let page = currentPage
        guard !refresher.isRefreshing(page) else { return }
        Task {
            let outcome = await refresher.refresh(page, settings: settings)
            statusTask?.cancel()
            withAnimation(.easeOut(duration: 0.2)) {
                statusText = outcome.text
            }
            statusTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    statusText = nil
                }
            }
        }
    }
}
