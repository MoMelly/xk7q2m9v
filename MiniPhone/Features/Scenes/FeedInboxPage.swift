import SwiftUI
import SwiftData

/// 西瓜皮底部「消息」那一格。
///
/// 私信和转帖是两条独立通道：数据上按 kind 分开存，界面上各占一段，
/// 点开也各进各的对话页。转帖页会带着那篇帖子作为上下文，私信页不带。
struct FeedInboxPage: View {
    let world: WorldStore
    let settings: SettingsStore

    @Environment(\.modelContext) private var context
    @Query private var companions: [Companion]
    /// 外层分享完传进来的 thread。正常启动都是 nil。
    var openThreadID: UUID? = nil
    var openTick: Int = 0

    @State private var segment: Segment = UserDefaults.standard.string(forKey: "previewState") == "feedShare"
        ? .share
        : .direct
    /// 截图状态直接落到对话页，正常启动为空。
    @State private var openedItem: FeedInboxItem?

    enum Segment: String, CaseIterable, Identifiable {
        case direct = "私信"
        case share = "分享"
        var id: String { rawValue }

        var kind: FeedInboxKind {
            self == .direct ? .directMessage : .postShare
        }
    }

    private var items: [FeedInboxItem] {
        world.state.feedInbox
            .filter { $0.kind == segment.kind }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func unread(_ target: Segment) -> Int {
        world.state.feedInbox.filter { $0.kind == target.kind && !$0.isRead }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            segmentRow

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            row(item)
                            RowDivider()
                                .padding(.leading, 70)
                        }
                    }
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
        }
        .navigationDestination(item: $openedItem) { item in
            destination(item)
        }
        .task { @MainActor in
            let state = UserDefaults.standard.string(forKey: "previewState") ?? ""
            guard ["feedChat", "feedShare", "feedCard"].contains(state) else { return }
            let kind: FeedInboxKind = state == "feedShare" ? .postShare : .directMessage
            openedItem = world.state.feedInbox.first { $0.kind == kind }
        }
        .onChange(of: openTick) { _, _ in
            guard let thread = openThreadID,
                  let item = world.state.feedInbox.first(where: { $0.threadID == thread }) else { return }
            segment = .direct
            openedItem = item
        }
    }

    private var header: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Text("消息")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.s)
        .padding(.bottom, PhoneMetrics.Space.xs)
    }

    private var segmentRow: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            ForEach(Segment.allCases) { target in
                Button {
                    segment = target
                } label: {
                    HStack(spacing: 5) {
                        Text(target.rawValue)
                            .font(.system(size: PhoneMetrics.FontSize.sub, weight: segment == target ? .semibold : .regular))
                        if unread(target) > 0 {
                            Text("\(unread(target))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Theme.brand))
                        }
                    }
                    .foregroundStyle(segment == target ? .white : AppSurface.light.label)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(height: 30)
                    .background(
                        Capsule().fill(
                            segment == target ? Theme.brand : AppSurface.light.rowSurface
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
    }

    private func row(_ item: FeedInboxItem) -> some View {
        Button {
            openedItem = item
            world.markFeedInboxRead(item.id)
        } label: {
            HStack(spacing: PhoneMetrics.Space.s) {
                FeedAvatar(name: item.companionName, isCharacter: true, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.companionName)
                            .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppSurface.light.label)
                        if !item.isRead {
                            Circle()
                                .fill(Theme.brand)
                                .frame(width: 6, height: 6)
                        }
                        Spacer(minLength: 0)
                        Text(TimeFormat.monthDayTime(item.createdAt))
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }

                    Text(item.message)
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .lineLimit(1)

                    if item.kind == .postShare {
                        Text("转了《\(item.noteTitle)》")
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(Theme.brand)
                            .lineLimit(1)
                    }
                }

                if item.kind == .postShare {
                    FeedNoteThumb(title: item.noteTitle, width: 44, height: 52)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(_ item: FeedInboxItem) -> some View {
        if let character = companions.first(where: { $0.uid.uuidString == item.companionUID }) {
            if item.kind == .postShare {
                FeedShareChatPage(item: item, character: character, settings: settings)
            } else {
                FeedChatPage(item: item, character: character, settings: settings)
            }
        } else {
            VStack(spacing: PhoneMetrics.Space.s) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 28))
                Text("这个人的资料不在了")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
            }
            .foregroundStyle(AppSurface.light.secondaryLabel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: segment == .direct ? "bubble.left.and.bubble.right" : "square.on.square")
                .font(.system(size: 26))
            Text(segment == .direct ? "还没有私信" : "还没有人转帖子给你")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("角色会自己找你说话，不用去点什么。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
