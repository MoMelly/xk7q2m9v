import SwiftUI
import SwiftData

/// 「信息」App 的会话列表。
///
/// 底部四格把功能摆到明面上：消息、通话、联系人、我的。上一版通话记录、
/// 角色资料、发起通话全藏在二级页或长按菜单里，列表层看不出该去哪点。
/// 顶栏是大标题 + 搜索 + 新建；列表保持深色玻璃。
struct ConversationListView: View {
    let settings: SettingsStore
    var onExit: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(WorldStore.self) private var world
    @Query(sort: [SortDescriptor(\Companion.sortIndex), SortDescriptor(\Companion.createdAt)])
    private var characters: [Companion]
    @Query private var profiles: [UserProfile]

    @State private var opened: Companion?
    @State private var showCreator = ["chatEditor", "avatarPicker"]
        .contains(UserDefaults.standard.string(forKey: "previewState") ?? "")
    @State private var showCallHistory = false
    /// 截图：冷启动点不到加号菜单，直接把这层建群页弹出来。
    @State private var showGroupCreator = UserDefaults.standard.string(forKey: "previewState") == "groupNew"
    @State private var pendingDelete: Companion?
    /// 截图用的启动 Tab，只影响预览状态，不落盘。
    @State private var tab: Tab = {
        switch UserDefaults.standard.string(forKey: "previewState") {
        case "chatMine": return .mine
        case "chatCalls": return .calls
        default: return .messages
        }
    }()
    @State private var query = ""
    /// 消息列表的两种顺序。默认按最近说话排，人多了切到按名字。
    @State private var byName = false
    @State private var callKind: CallKind?
    @State private var callTarget: Companion?
    @State private var callModel = ChatViewModel()

    enum Tab: String, CaseIterable, Identifiable {
        case messages = "消息"
        case calls = "通话"
        case contacts = "联系人"
        case mine = "我的"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .messages: return "bubble.left.and.bubble.right"
            case .calls: return "phone"
            case .contacts: return "person.2"
            case .mine: return "person.crop.circle"
            }
        }
    }

    private var visibleCharacters: [Companion] {
        let base = characters.filter { !$0.isFeedOnly }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.lastPreviewText.localizedCaseInsensitiveContains(query)
        }
    }

    /// 通话只认「一个人」：群不能接电话，拨过去该谁接说不通。
    private var callableCharacters: [Companion] {
        visibleCharacters.filter { !$0.isGroup }
    }

    /// 快捷拨号是回拨：按 sortIndex 取第一个等于随机拨给某个人，
    /// 通话要的是最近跟我说过话的那个，按钮上也把名字写出来。
    private var recentCallable: Companion? {
        callableCharacters
            .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
            .first
    }

    var body: some View {
        ZStack {
            ChatBackgroundView(settings: settings).ignoresSafeArea()

            if let opened {
                ChatView(
                    character: opened,
                    settings: settings,
                    onExit: { withAnimation(.easeInOut(duration: 0.2)) { self.opened = nil } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            } else {
                listLayer
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showCreator) {
            CharacterEditorView(character: nil, onFinish: { showCreator = false })
        }
        // 加号原来直接开「新建角色」。建群本来也能建——角色编辑器里有个
        // 「群聊」开关——但那条路要先造一个空角色、再手打一串成员名，
        // 没人会把它当成「新建群聊」。这里给两条明路。
        .sheet(isPresented: $showGroupCreator) {
            GroupEditorView(
                onCreate: { group in
                    showGroupCreator = false
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        opened = group
                    }
                },
                onCancel: { showGroupCreator = false }
            )
        }
        .sheet(isPresented: $showCallHistory) {
            CallScene(world: world, onClose: { showCallHistory = false })
        }
        .fullScreenCover(item: $callKind) { kind in
            if let callTarget {
                CallOverlay(
                    character: callTarget,
                    kind: kind,
                    settings: settings,
                    model: callModel,
                    onEnd: { callKind = nil }
                )
            }
        }
        .confirmationDialog(
            "删除「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除这个角色和全部聊天记录", role: .destructive) {
                if let target = pendingDelete {
                    // 世界状态是另一份按名字存的数据，得一起清。
                    WorldStore.shared.purgePerson(named: target.name)
                    context.delete(target)
                    try? context.save()
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - 框架

    private var listLayer: some View {
        VStack(spacing: 0) {
            header
            // 「我的」没有可搜的东西，搜索栏在这格是占地方的摆设。
            if tab != .mine {
                searchBar
            }

            switch tab {
            case .messages: messagesList
            case .calls: callsList
            case .contacts: contactsList
            case .mine: myProfile
            }

            tabBar
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            GlassIconButton(symbol: "chevron.left", action: onExit)

            VStack(alignment: .leading, spacing: 2) {
                Text("信息")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.cream)
                Text(visibleCharacters.isEmpty ? "还没有角色" : "\(visibleCharacters.count) 个会话")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream.opacity(0.5))
            }

            Spacer(minLength: 0)

            GlassMenuButton(symbol: "plus") {
                Button {
                    showCreator = true
                } label: {
                    Label("新建角色", systemImage: "person.badge.plus")
                }

                Button {
                    showGroupCreator = true
                } label: {
                    Label("新建群聊", systemImage: "person.2.badge.plus")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
            TextField("搜索会话或联系人", text: $query)
                .font(.system(size: 13))
                .foregroundStyle(Theme.cream)
                .tint(Theme.mint)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.cream.opacity(0.55))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .glassSurface(cornerRadius: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 底部页签：iOS 26 那种悬浮圆角玻璃栏——四边留缝、胶囊圆角、
    /// 半透明玻璃底，不再是通栏压在页底的深绿色块。
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab == item ? item.symbol + ".fill" : item.symbol)
                            .font(.system(size: 17))
                        Text(item.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(tab == item ? Theme.mint : Theme.cream.opacity(0.46))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .glassSurface(cornerRadius: 26, tint: Color.white.opacity(ThemeStore.shared.isNight ? 0.12 : 0.42))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    // MARK: - 消息

    private var messagesList: some View {
        Group {
            if visibleCharacters.isEmpty {
                emptyState
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 0) {
                    orderSwitch

                    ScrollView {
                        if byName {
                            groupedMessages
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleCharacters) { character in
                                    row(character)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
    }

    /// 「按时间 / 按名字」。会话默认按最近说话排，那是每天都要用的顺序；
    /// 角色攒到十几个之后，找一个不常聊的人只能靠搜，所以留一个分组入口。
    private var orderSwitch: some View {
        HStack(spacing: 6) {
            ForEach([false, true], id: \.self) { value in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { byName = value }
                } label: {
                    Text(value ? "按名字" : "按时间")
                        .font(.system(size: 11, weight: byName == value ? .semibold : .regular))
                        .foregroundStyle(byName == value ? Theme.deepGreen : Theme.cream.opacity(0.6))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(
                            Capsule().fill(byName == value ? Theme.mint : Theme.cream.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var groupedMessages: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(ContactGrouping.sections(visibleCharacters)) { section in
                HStack(spacing: 8) {
                    Text(section.id)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mint)

                    Rectangle()
                        .fill(Theme.mint.opacity(0.18))
                        .frame(height: 1)
                }
                .padding(.top, 10)
                .padding(.bottom, 6)

                ForEach(section.items) { character in
                    row(character)
                        .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 通话

    private var callsList: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(CallKind.allCases) { kind in
                        Button {
                            guard let target = recentCallable else { return }
                            callTarget = target
                            callKind = kind
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: kind.symbol)
                                    .font(.system(size: 20))
                                Text(kind.title)
                                    .font(.system(size: 12, weight: .medium))
                                Text(recentCallable?.name ?? "还没人能打")
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(Theme.deepGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                            .background(Capsule().fill(Theme.mint.opacity(0.92)))
                        }
                        .buttonStyle(.plain)
                        .disabled(recentCallable == nil)
                    }
                }

                Button {
                    showCallHistory = true
                } label: {
                    HStack {
                        Image(systemName: "clock")
                        Text("通话记录")
                            .font(.system(size: 14, weight: .medium))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Theme.cream)
                    .padding(14)
                    .glassSurface(cornerRadius: 18)
                }
                .buttonStyle(.plain)

                Text("选一个人打过去")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cream.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                ForEach(callableCharacters) { character in
                    HStack(spacing: 12) {
                        AvatarBubble(character: character, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(character.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.cream)
                            Text(character.lastMessageAt.map { "上次聊于 \(TimeFormat.monthDayTime($0))" } ?? "还没聊过")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.cream.opacity(0.5))
                        }
                        Spacer(minLength: 0)
                        Button {
                            callTarget = character
                            callKind = .voice
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.deepGreen)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.mint))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .glassSurface(cornerRadius: 18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - 我的

    private var myProfile: some View {
        Group {
            if let profile = profiles.first(where: { $0.isDefault }) ?? profiles.first {
                MyProfilePage(profile: profile, settings: settings)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.cream.opacity(0.5))
                    Text("还没有我的资料")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(Theme.cream.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 联系人

    private var contactsList: some View {
        ContactDirectoryView(
            characters: visibleCharacters,
            footer: "「我的人设」和「世界」在桌面的设置里。通话记录、角色资料都在信息里，不用长按。"
        ) { character in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                opened = character
            }
        }
    }

    // MARK: - 行

    private func row(_ character: Companion) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                opened = character
            }
        } label: {
            HStack(spacing: 12) {
                AvatarBubble(character: character, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(character.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(1)

                        if character.isGroup {
                            tag("群")
                        }
                        if CharacterClock.isAsleep(character) {
                            tag("睡了")
                        }
                    }

                    Text(character.lastPreviewText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cream.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(character.lastMessageAt.map { CharacterClock.listTimestamp($0) } ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.cream.opacity(0.35))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.mint.opacity(0.35))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .glassSurface(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                pendingDelete = character
            } label: {
                Label("删除角色", systemImage: "trash")
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.mint.opacity(0.8))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.mint.opacity(0.14))
            )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("先造一个人")
                .font(Theme.serif(24, weight: .medium))
                .foregroundStyle(Theme.cream)

            Text("写一段人设，选一种对话形式，它就会按自己的作息和说话方式活着。\n手上已经有酒馆的角色卡（PNG 或 JSON）也可以直接导入。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mint.opacity(0.7))
                .lineSpacing(5)

            Button {
                showCreator = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("新建角色")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.deepGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Theme.mint)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassSurface(cornerRadius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}
