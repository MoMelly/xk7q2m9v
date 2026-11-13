import SwiftUI
import SwiftData

/// 角色详情。聊天页右上角那个入口进来的地方。
///
/// 用系统设置的结构：一张身份卡 + 几组整宽分组，每行点进去才是真页面。
/// 之前这些入口全塞在聊天页的一个 `confirmationDialog` 里，
/// 想找「他记得我什么」根本没有地方点。
struct CharacterDetailPage: View {
    @Bindable var character: Companion
    let world: WorldStore
    let settings: SettingsStore
    var onRegenerate: (() -> Void)? = nil
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]
    @State private var showEditor = false
    @State private var showClearConfirm = false
    @State private var calendarDenied = false
    private var letterService: LetterService { .shared }
    @State private var letterMessage: String?
    /// 拍一拍后缀的编辑框。
    @State private var showPatEditor = false
    @State private var patDraft = ""
    /// 查手机。从他自己的详情页进来，直接开他这一台。
    @State private var showPhone = false

    private var person: PersonMemory? {
        world.state.person(named: character.name)
    }

    private var factCount: Int {
        person?.facts.count ?? 0
    }

    /// 这一段会话用的身份名。空串表示用默认的，界面上不写字。
    private var personaName: String {
        let active = IdentityScope.storedUID
        if !active.isEmpty,
           let matched = profiles.first(where: { $0.uid.uuidString == active }) {
            return matched.name
        }
        return profiles.first(where: { $0.isDefault })?.name ?? "我"
    }

    /// 行尾的小字。只写「几个能用」，全开时不写满——
    /// 一行放不下具体名字，点进去看更准。
    private var stickerSummary: String {
        let total = StickerLibrary.shared.items.count
        guard total > 0 else { return "没有表情" }
        let open = StickerLibrary.shared.available(for: character).count
        return open == total ? "全部 \(total) 个" : "\(open) / \(total)"
    }

    /// 截图：藏在详情里两三级的页面，冷启动点不到按钮，按状态名直接落到那一层。
    ///
    /// - `board`：看板
    /// - `statePanel`：状态面板
    /// - `anonBox`：匿名提问箱
    ///
    /// 正常启动读不到这个键，一条都不会命中。
    private var previewLeaf: String? {
        UserDefaults.standard.string(forKey: "previewState")
    }

    private var previewLeafPage: some View {
        switch previewLeaf {
        case "board":
            AnyView(CharacterBoardPage(character: character, world: world))
        case "statePanel", "statePanelIdentity":
            AnyView(StatePanelPage(character: character, world: world))
        case "anonBox":
            AnyView(AnonymousBoxPage(character: character, world: world, settings: settings))
        case "groupMemory":
            AnyView(CharacterMemoryPage(character: character, world: world))
        case "groupMembers":
            AnyView(GroupMembersPage(character: character, world: world))
        default:
            AnyView(detailBody)
        }
    }

    var body: some View {
        previewLeafPage
    }

    /// 「TA 的」这一组。
    ///
    /// 群不是人。主页、看板、日程、好感度、提问箱、手机这些东西，
    /// 原来对群也一律列出来——点进群的主页是一张空卡，好感度拖到 100
    /// 也不会让任何一句台词变。群只留两样：群里发生过什么，和群里都有谁。
    @ViewBuilder
    private var infoRows: some View {
        if character.isGroup {
            NavigationLink {
                CharacterMemoryPage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "brain.head.profile",
                    symbolTint: Theme.IconTint.purple,
                    title: "群里的记忆",
                    value: world.memorySummary(for: character.name).isEmpty ? nil : "写得下",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            // 这一行原来只显示「几个人」的灰字，加人得回角色编辑器里手打
            // 成员名。改成能点进去：加人、移人、改群名都在里面。
            NavigationLink {
                GroupMembersPage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "person.2.fill",
                    symbolTint: Theme.IconTint.teal,
                    title: "群成员",
                    value: groupMemberCount == 0 ? "还没写" : "\(groupMemberCount) 人",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                CharacterHomePage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "person.crop.circle.fill",
                    symbolTint: Theme.IconTint.orange,
                    title: "主页",
                    value: "\(character.totalReplies)",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink {
                CharacterBoardPage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "person.crop.rectangle.fill",
                    symbolTint: Theme.IconTint.rose,
                    title: "看板",
                    value: "点一下有反应",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink {
                CharacterDayPage(world: world, character: character)
            } label: {
                GroupedRow(
                    symbol: "calendar",
                    symbolTint: Theme.IconTint.pink,
                    title: "今天的日程",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink {
                CharacterMemoryPage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "brain.head.profile",
                    symbolTint: Theme.IconTint.purple,
                    title: "记忆",
                    value: factCount > 0 ? "\(factCount) 条" : nil,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink {
                AnonymousBoxPage(character: character, world: world, settings: settings)
            } label: {
                GroupedRow(
                    symbol: "questionmark.bubble.fill",
                    symbolTint: Theme.IconTint.indigo,
                    title: "匿名提问箱",
                    value: world.questions(for: character.name).isEmpty
                        ? "还没人问"
                        : "\(world.questions(for: character.name).count) 个",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink {
                StatePanelPage(character: character, world: world)
            } label: {
                GroupedRow(
                    symbol: "gauge.with.dots.needle.67percent",
                    symbolTint: Theme.IconTint.green,
                    title: "状态面板",
                    value: AffinityScale.stage(of: world.affinity(for: character.name)).label,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            RowDivider()

            // 查手机。桌面那个图标是按「最近说过话的人」开的，
            // 从这个人的详情页进来才是确定的「看他这一台」。
            Button {
                showPhone = true
            } label: {
                GroupedRow(
                    symbol: "iphone.gen3",
                    symbolTint: Theme.IconTint.gray,
                    title: "\(character.name) 的手机",
                    value: world.hasPhone(for: character.name) ? "已生成" : "还没打开",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// 这一组的脚注。群要说明为什么少了几项，不然会像功能坏了。
    private var infoFooter: String? {
        character.isGroup
            ? "群没有主页、日程和好感度。这些是「一个人」才有的东西，群只记得住发生过什么。"
            : nil
    }

    /// 行尾的音色小字。没设过就写「自动」，设过写音色名。
    private var voiceSummary: String {
        SpeechService.voiceShortName(id: character.voiceID) ?? "自动"
    }

    /// 群成员数从「成员」那段文字里数。它是自由文本，不是结构化的名单，
    /// 逗号、顿号、换行都有人用，拆分统一走 `GroupRoster`。
    private var groupMemberCount: Int {
        GroupRoster.names(from: character.membersNote).count
    }

    private var detailBody: some View {
        AppScreen(title: "详情", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    identityCard

                    GroupedSection(character.isGroup ? "这个群" : "TA 的", footer: infoFooter) {
                        infoRows
                    }

                    // 日历是「一个人才有的东西」。群没有自己的日历，
                    // 这个开关打开也只会去读用户本人的日程，然后当成群看过。
                    if !character.isGroup {
                        GroupedSection(
                            "边界",
                            footer: calendarDenied
                                ? "系统里的日历权限被拒绝了，去「设置 → 小手机 → 日历」打开。"
                                : UserCalendarBridge.statusLine(for: character.name)
                        ) {
                            Toggle(isOn: calendarBinding) {
                                Text("可以看我日历上的安排")
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(Theme.label)
                            }
                            .tint(Theme.tint)
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: PhoneMetrics.Row.single)
                        }
                    }

                    GroupedSection("设定") {
                        Button {
                            showEditor = true
                        } label: {
                            GroupedRow(
                                symbol: "text.badge.checkmark",
                                symbolTint: Theme.IconTint.green,
                                title: "人设、签名与标签",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        RowDivider()

                        // 身份不再按会话选：以前每认识一个角色都要选一次
                        // 「我用谁跟他说话」，攒到十几个角色就是十几遍。
                        // 现在统一在「我的 → 切换身份」切一次，整个信息页都跟着换。
                        GroupedRow(
                            symbol: "theatermasks.fill",
                            symbolTint: Theme.IconTint.indigo,
                            title: "现在用谁的身份",
                            value: personaName,
                            showsChevron: false
                        )

                        RowDivider()

                        NavigationLink {
                            CharacterStickerPage(character: character)
                        } label: {
                            GroupedRow(
                                symbol: "face.smiling.fill",
                                symbolTint: Theme.IconTint.pink,
                                title: "能用哪些表情",
                                value: stickerSummary,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        // 拍一拍后缀。角色这边单独一条：双击 TA 的头像时用。
                        // 群不给：拍一个群，这句话该谁说？
                        if !character.isGroup {
                            RowDivider()

                            // 音色是「一个人」的属性：群里的每一句由成员自己那一档念，
                            // 群名下不设嗓子。
                            NavigationLink {
                                CharacterVoicePage(character: character, settings: settings)
                            } label: {
                                GroupedRow(
                                    symbol: "waveform",
                                    symbolTint: Theme.IconTint.pink,
                                    title: "TA 的声音",
                                    value: voiceSummary,
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)

                            RowDivider()

                            Button {
                                patDraft = character.patSuffix
                                showPatEditor = true
                            } label: {
                                GroupedRow(
                                    symbol: "hand.tap.fill",
                                    symbolTint: Theme.IconTint.orange,
                                    title: "拍一拍后缀",
                                    value: character.patSuffix.isEmpty ? "的肩膀" : character.patSuffix,
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 信是一个人写给另一个人的。群不写信：落款该署谁的名？
                    if !character.isGroup {
                        GroupedSection("信件", footer: letterMessage) {
                            Button(action: writeLetter) {
                                GroupedRow(
                                    symbol: "envelope.fill",
                                    symbolTint: Theme.IconTint.orange,
                                    title: letterService.isWriting(character) ? "正在写…" : "让 TA 写封信",
                                    showsChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(letterService.isWriting(character))
                        }
                    }

                    GroupedSection("这个会话") {
                        if let onRegenerate {
                            Button(action: onRegenerate) {
                                GroupedRow(
                                    symbol: "arrow.clockwise",
                                    symbolTint: Theme.IconTint.indigo,
                                    title: "重新生成最后一条"
                                )
                            }
                            .buttonStyle(.plain)

                            RowDivider()
                        }

                        Button {
                            showClearConfirm = true
                        } label: {
                            GroupedRow(
                                symbol: "trash.fill",
                                symbolTint: Theme.IconTint.gray,
                                title: "清空对话记录"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .alert("拍一拍后缀", isPresented: $showPatEditor) {
            TextField("比如：的后颈", text: $patDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                character.patSuffix = patDraft.trimmingCharacters(in: .whitespaces)
            }
        } message: {
            Text("双击 TA 的头像时，会显示成「\(character.name)\(patDraft.trimmingCharacters(in: .whitespaces).isEmpty ? "的肩膀" : patDraft)」。")
        }
        .sheet(isPresented: $showEditor) {
            CharacterEditorView(character: character, onFinish: { showEditor = false })
        }
        .onAppear {
            // 截图：世界书列表藏在「详情 → 编辑器 → 世界书」三级深处，
            // 按状态名逐层打开；编辑器那边再开最里面的 sheet。
            if previewLeaf == "worldEntries" {
                showEditor = true
            }
        }
        .sheet(isPresented: $showPhone) {
            CharacterPhoneScene(
                world: world,
                settings: settings,
                initialOwner: character.name,
                onClose: { showPhone = false }
            )
        }
        .confirmationDialog("清空对话记录", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) { clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("聊天记录、他记得的事、这几天的日程都会清掉，不能恢复。好感度保留。")
        }
    }

    // MARK: - 身份卡

    private var identityCard: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            AvatarBubble(character: character, size: 72)

            VStack(spacing: 5) {
                Text(character.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.label)

                Text(character.signature.isEmpty ? "还没有写签名" : character.signature)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PhoneMetrics.Space.xl)

                if !character.tags.isEmpty {
                    tagRow
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.l)
    }

    private var tagRow: some View {
        HStack(spacing: 6) {
            ForEach(character.tags.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Theme.tint.opacity(0.12))
                    )
            }
        }
    }

    // MARK: - 行为

    private var calendarBinding: Binding<Bool> {
        Binding(
            get: { character.canReadCalendar },
            set: { newValue in
                guard newValue else {
                    character.canReadCalendar = false
                    try? context.save()
                    return
                }

                Task { @MainActor in
                    let granted = await UserCalendarBridge.requestAccess()
                    character.canReadCalendar = granted
                    calendarDenied = !granted
                    try? context.save()
                }
            }
        )
    }

    /// 写信是一次用户动作。写完给一句回执，信本体在桌面的「信件」里。
    private func writeLetter() {
        guard !letterService.isWriting(character) else { return }
        letterMessage = nil
        Task {
            if let error = await letterService.write(character: character, settings: settings) {
                letterMessage = error
            } else {
                letterMessage = "写好了，去「信件」里看。"
            }
        }
    }

    private func clearHistory() {
        for message in character.messages {
            context.delete(message)
        }
        character.memorySummary = ""
        character.memoryCursor = nil
        // 记忆条目和日程也是从这些对话里长出来的，一起清。
        // 只清消息的话，记忆页还翻得到旧事实，模型在空对话里照样提起旧事。
        WorldStore.shared.clearPersonMemory(named: character.name)
        try? context.save()
    }
}
