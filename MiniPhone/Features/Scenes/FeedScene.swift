import SwiftUI

/// 西瓜皮。
///
/// 结构照抄真机：顶部搜索条 + 关注/发现两个页签，中间双列瀑布流，
/// 底部只有三格——首页、发布、我的。发布只走中间那个红色按钮，
/// 右上角留给刷新：点一下，模型出一整轮的帖子。
struct FeedScene: View {
    let world: WorldStore
    let settings: SettingsStore
    var onClose: () -> Void

    /// 截图状态 `feedProfile` 直接落到「我的」，省掉一层点击；正常启动都是首页。
    @State private var phoneTab: PhoneTab = UserDefaults.standard.string(forKey: "previewState") == "feedProfile"
        ? .mine
        : .home
    @State private var feedTab: FeedTab = .discover
    @State private var isComposing = false
    /// 直接取单例而不是存进 @State：@State 的初始化不在 body 里，
    /// 拿 @MainActor 的 shared 会踩隔离检查。在 body 里读一次，观察照样成立。
    private var refresher: RefreshService { .shared }
    @State private var statusText: String?
    @State private var statusTask: Task<Void, Never>?

    enum PhoneTab: String, CaseIterable, Identifiable {
        case home = "首页"
        case mine = "我的"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .home: return "house"
            case .mine: return "person"
            }
        }
    }

    enum FeedTab: String, CaseIterable, Identifiable {
        case discover = "发现"
        case following = "关注"

        var id: String { rawValue }
    }

    private var notes: [FeedNote] {
        let all = world.state.feed.sorted { $0.postedAt > $1.postedAt }
        switch feedTab {
        case .discover: return all
        case .following: return all.filter { $0.authorUID != nil }
        }
    }

    var body: some View {
        AppScreen(
            title: phoneTab == .mine ? "" : "西瓜皮",
            surface: .light,
            onClose: onClose,
            trailingSymbol: "arrow.clockwise",
            trailingAction: refreshFeed,
            transparentBar: phoneTab == .mine
        ) {
            VStack(spacing: 0) {
                if phoneTab == .home {
                    searchBar
                }

                if phoneTab == .home {
                    feedTabs
                }

                if let statusText {
                    RefreshStatusStrip(text: statusText, isLoading: refresher.isRefreshing(.feed))
                }

                if phoneTab == .home {
                    content
                } else {
                    FeedProfilePage(world: world, onCompose: { isComposing = true })
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
        if notes.isEmpty {
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
                                        FeedDetailPage(note: note, world: world)
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
                if item == .mine {
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

    // MARK: - 刷新

    private func refreshFeed() {
        guard !refresher.isRefreshing(.feed) else { return }
        Task {
            let outcome = await refresher.refresh(.feed, settings: settings)
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
