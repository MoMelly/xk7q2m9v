import SwiftUI

/// 西瓜皮。
///
/// 结构照抄真机：顶部搜索条、两个页签、双列瀑布流。封面不是图片，
/// 由 `NoteCover` 用标题现场排出来——这样笔记再多也不占包体。
///
/// 「关注」页只留角色发的笔记：`authorUID` 有值才算，路人的帖子不会混进来。
struct FeedScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var tab: Tab = .discover
    @State private var isComposing = false

    enum Tab: String, CaseIterable, Identifiable {
        case discover = "发现"
        case following = "关注"

        var id: String { rawValue }
    }

    private var notes: [FeedNote] {
        let all = world.state.feed.sorted { $0.postedAt > $1.postedAt }
        switch tab {
        case .discover: return all
        case .following: return all.filter { $0.authorUID != nil }
        }
    }

    var body: some View {
        AppScreen(
            title: "西瓜皮",
            surface: .light,
            onClose: onClose,
            trailingSymbol: "square.and.pencil",
            trailingAction: { isComposing = true }
        ) {
            VStack(spacing: 0) {
                searchBar
                tabs
                content
            }
        }
        .sheet(isPresented: $isComposing) {
            NoteComposer(world: world, onClose: { isComposing = false })
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

    private var tabs: some View {
        HStack(spacing: PhoneMetrics.Space.l) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 5) {
                        Text(item.rawValue)
                            .font(.system(
                                size: PhoneMetrics.FontSize.sub,
                                weight: tab == item ? .semibold : .regular
                            ))
                            .foregroundStyle(
                                tab == item ? AppSurface.light.label : AppSurface.light.secondaryLabel
                            )

                        Capsule()
                            .fill(tab == item ? AppSurface.light.label : .clear)
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
                let columns = split(into: 2, width: width)

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
                    .padding(.top, PhoneMetrics.Space.xs)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "book.closed")
                .font(.system(size: 26))
            Text(tab == .following ? "角色还没发过笔记" : "还没刷出笔记")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("多聊几句，这里会跟着变。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 按估算高度把笔记分到两列，每次放进当前更矮的那一列。
    ///
    /// 真做瀑布流要量每一张的实际高度，那得等布局完成再回调，
    /// 列表一滚动就会抖。按封面比例 + 标题行数估算已经够平。
    private func split(into count: Int, width: CGFloat) -> [[FeedNote]] {
        var columns = Array(repeating: [FeedNote](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)

        for note in notes {
            let target = heights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            columns[target].append(note)
            heights[target] += estimatedHeight(of: note, width: width)
        }
        return columns
    }

    private func estimatedHeight(of note: FeedNote, width: CGFloat) -> CGFloat {
        let ratio = FeedCard.aspectRatio(for: note.coverSeed)
        let cover = width / ratio
        let titleLines = min(2, max(1, note.title.count / 9 + 1))
        return cover + CGFloat(titleLines) * 20 + 40 + PhoneMetrics.Space.xs
    }
}

/// 西瓜皮里的头像。
///
/// 有 `authorUID` 的是角色，红底首字；没有的是路人和匿名评论，
/// 给一颗圆西瓜——这是这个 App 唯一允许出现的默认头像。
struct FeedAvatar: View {
    var name: String
    var isCharacter: Bool
    var size: CGFloat = 22

    var body: some View {
        if isCharacter {
            Circle()
                .fill(Theme.brand)
                .frame(width: size, height: size)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else {
            WatermelonMark(size: size)
        }
    }
}

/// 一张笔记卡。
struct FeedCard: View {
    let note: FeedNote
    let width: CGFloat

    /// 封面比例也由 seed 决定，双列才不会像贴了两排同样大小的砖。
    static func aspectRatio(for seed: Int) -> CGFloat {
        [0.80, 1.00, 1.25][StableSeed.index(seed, count: 3)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoteCover(title: note.title, tag: note.tag, seed: note.coverSeed)
                .frame(width: width, height: width / Self.aspectRatio(for: note.coverSeed))
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))

            Text(note.title)
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, PhoneMetrics.Space.xs)

            HStack(spacing: 4) {
                FeedAvatar(
                    name: note.authorName,
                    isCharacter: note.authorUID != nil,
                    size: 15
                )

                Text(note.authorName)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "heart")
                    .font(.system(size: 10))
                Text("\(note.likes)")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
            }
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .padding(.top, 5)
        }
        .padding(.bottom, PhoneMetrics.Space.xxs)
    }
}
