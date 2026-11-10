import SwiftUI
import SwiftData

/// 「文游」App：文字游戏的入口与存档列表。
///
/// 开局流程：填故事线 → 模型起标题并挑参与角色（也可以自己挑）→ 进阅读页。
/// 一局玩完按记忆模式回写，存档留在本页可以回看。
struct StoryGameScene: View {
    let settings: SettingsStore
    var onClose: () -> Void

    @State private var viewModel = StoryGameViewModel()
    @State private var showSetup = false
    /// 删档之后强制重建列表。存档是扫目录读出来的，删完不重算一遍，
    /// 那一行会一直留在屏幕上，看着像没删掉。
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if viewModel.session != nil {
                StoryReadPage(
                    settings: settings,
                    viewModel: viewModel,
                    onBack: { viewModel.close() }
                )
            } else {
                AppScreen(title: "文游", surface: .paper, onClose: onClose) {
                    archiveList
                }
                .sheet(isPresented: $showSetup) {
                    StorySetupPage(settings: settings, viewModel: viewModel)
                }
            }
        }
        .onAppear {
            // 截图：`storyEnd` 直接进阅读页，拍「结局 · xxx」那一行。
            // 正常启动读不到这个键；存档列表点进去也是同一条路。
            guard UserDefaults.standard.string(forKey: "previewState") == "storyEnd",
                  viewModel.session == nil,
                  let archived = StoryArchive.loadAll().first else { return }
            viewModel.session = archived
        }
    }

    private var archiveList: some View {
        let sessions = StoryArchive.loadAll()

        return Group {
            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            Button {
                                viewModel.resume(
                                    session,
                                    roster: StoryGameViewModel.roster(context: modelContext)
                                )
                            } label: {
                                row(session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    StoryArchive.delete(session)
                                    reloadToken += 1
                                } label: {
                                    Label("删掉这一局", systemImage: "trash")
                                }
                            }

                            if index != sessions.count - 1 {
                                Rectangle()
                                    .fill(Theme.StoryPaper.rule.opacity(0.55))
                                    .frame(height: 0.6)
                                    .padding(.leading, 2)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .id(reloadToken)
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("❖")
                .font(.system(size: 15))
                .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.55))

            Text("还没有故事")
                .font(Theme.serif(19, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(Theme.StoryPaper.ink)

            Text("写一条故事线，挑上角色，就能开场")
                .font(Theme.serif(12.5))
                .foregroundStyle(Theme.StoryPaper.inkSoft)

            Button {
                showSetup = true
            } label: {
                Text("开一个新故事")
                    .font(Theme.serif(14, weight: .medium))
                    .foregroundStyle(Theme.StoryPaper.paper)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.StoryPaper.vermilion))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 一局故事在目录里的一行。
    ///
    /// 不用 `List`：分组列表的底色、缩进、选中高亮都是系统给的，
    /// 放在纸上会变成「纸里嵌了一段设置页」。这里只要一行字和一条细线。
    private func row(_ session: StorySession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("《\(session.title)》")
                    .font(Theme.serif(16, weight: .semibold))
                    .foregroundStyle(Theme.StoryPaper.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if session.isEnded {
                    Text(session.endingLabel ?? "已结束")
                        .font(Theme.serif(11))
                        .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("在写")
                        .font(Theme.serif(11))
                        .foregroundStyle(Theme.StoryPaper.inkSoft)
                }
            }

            Text(session.characterNames.joined(separator: " · "))
                .font(.system(size: 11, weight: .medium))
                .kerning(1.1)
                .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.7))

            Text(session.premise)
                .font(Theme.serif(12.5))
                .foregroundStyle(Theme.StoryPaper.inkSoft)
                .lineLimit(2)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(TimeFormat.callTime(session.updatedAt))
                .font(.system(size: 10))
                .foregroundStyle(Theme.StoryPaper.inkSoft.opacity(0.7))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// 开局页：故事线、标题、角色全是使用者自己定。
///
/// 之前有过一个「让 AI 起标题、挑角色」的按钮，她实测点名不要——
/// 标题她自己起，角色她自己挑，AI 只负责把故事讲好。
struct StorySetupPage: View {
    let settings: SettingsStore
    @Bindable var viewModel: StoryGameViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var premise = ""
    @State private var title = ""
    @State private var selected: Set<UUID> = []

    private var roster: [Companion] { StoryGameViewModel.roster(context: modelContext) }

    private var canStart: Bool {
        !premise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selected.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.l) {
                    premiseBlock
                    titleBlock
                    rosterBlock
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(Theme.StoryPaper.paper)
            .navigationTitle("新故事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.StoryPaper.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(Theme.StoryPaper.vermilion)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开场") {
                        // 用当前默认身份，不是「查到的第一个身份」：
                        // 多身份时第一个不一定是正在用的那个，玩家名会张冠李戴。
                        let player = UserProfileBook
                            .resolve(uid: "", in: modelContext)?.name ?? "我"
                        // 顺序按名单走。`selected` 是无序 Set，直接 `Array()` 会让
                        // 同一次选择的角色顺序每次都不同，正文里的称呼跟着乱。
                        let ordered = roster
                            .filter { selected.contains($0.uid) }
                            .map(\.uid)
                        Task {
                            await viewModel.start(
                                title: title,
                                premise: premise,
                                uids: ordered,
                                roster: roster,
                                playerName: player,
                                settings: settings
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canStart || viewModel.isStreaming)
                }
            }
        }
    }

    // MARK: - 故事线

    private var premiseBlock: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text("故事线")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.StoryPaper.inkSoft)
            TextEditor(text: $premise)
                .font(Theme.serif(15))
                .foregroundStyle(Theme.StoryPaper.ink)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(PhoneMetrics.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(Theme.StoryPaper.card)
                )
                .overlay(alignment: .topLeading) {
                    if premise.isEmpty {
                        Text("想玩什么？比如「放学后和她在天台看日落」")
                            .font(Theme.serif(15))
                            .foregroundStyle(Theme.StoryPaper.inkSoft)
                            .padding(PhoneMetrics.Space.s + 4)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 标题

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text("标题")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.StoryPaper.inkSoft)
            TextField("给这个故事起个名", text: $title)
                .font(Theme.serif(15))
                .foregroundStyle(Theme.StoryPaper.ink)
                .padding(PhoneMetrics.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(Theme.StoryPaper.card)
                )
        }
    }

    // MARK: - 角色

    private var rosterBlock: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text("参与角色（1~3 个）")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.StoryPaper.inkSoft)

            FlowChips(
                items: roster.map { (id: $0.uid, label: $0.name) },
                isSelected: { selected.contains($0) },
                toggle: { uid in
                    if selected.contains(uid) {
                        selected.remove(uid)
                    } else if selected.count < 3 {
                        selected.insert(uid)
                    }
                }
            )
        }
    }
}

/// 简单的流式换行选择胶囊。就这一处用，不值得引布局库。
struct FlowChips: View {
    let items: [(id: UUID, label: String)]
    let isSelected: (UUID) -> Bool
    let toggle: (UUID) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: PhoneMetrics.Space.xs)], spacing: PhoneMetrics.Space.xs) {
            ForEach(items, id: \.id) { item in
                Button {
                    toggle(item.id)
                } label: {
                    Text(item.label)
                        .font(Theme.serif(15))
                        .lineLimit(1)
                        .foregroundStyle(isSelected(item.id) ? Theme.StoryPaper.vermilion : Theme.StoryPaper.ink)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(isSelected(item.id) ? Theme.StoryPaper.card : Theme.StoryPaper.card)
                        )
                        .overlay {
                            Capsule().strokeBorder(Theme.StoryPaper.rule, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
