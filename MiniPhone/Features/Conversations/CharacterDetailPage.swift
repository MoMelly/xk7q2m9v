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

    private var person: PersonMemory? {
        world.state.people.first { $0.name == character.name }
    }

    private var factCount: Int {
        person?.facts.count ?? 0
    }

    /// 这一段会话用的身份名。空串表示用默认的，界面上不写字。
    private var personaName: String {
        if !character.personaUID.isEmpty,
           let matched = profiles.first(where: { $0.uid.uuidString == character.personaUID }) {
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

    var body: some View {
        AppScreen(title: "详情", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    identityCard

                    GroupedSection("TA 的") {
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
                    }

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

                        NavigationLink {
                            PersonaPickerPage(character: character)
                        } label: {
                            GroupedRow(
                                symbol: "theatermasks.fill",
                                symbolTint: Theme.IconTint.indigo,
                                title: "我以谁的身份",
                                value: personaName,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

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

                        RowDivider()

                        // 拍一拍后缀。角色这边单独一条：双击 TA 的头像时用。
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
        .confirmationDialog("清空对话记录", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) { clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("聊天记录和记忆摘要都会清掉，不能恢复。")
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
        try? context.save()
    }
}
