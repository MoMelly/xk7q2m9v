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

    var body: some View {
        Group {
            if viewModel.session != nil {
                StoryReadPage(
                    settings: settings,
                    viewModel: viewModel,
                    onBack: { viewModel.close() }
                )
            } else {
                AppScreen(title: "文游", surface: .light, onClose: onClose) {
                    archiveList
                }
                .sheet(isPresented: $showSetup) {
                    StorySetupPage(settings: settings, viewModel: viewModel)
                }
            }
        }
    }

    private var archiveList: some View {
        let sessions = StoryArchive.loadAll()

        return Group {
            if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessions) { session in
                        Button {
                            viewModel.resume(session, roster: StoryGameViewModel.roster(context: modelContext))
                        } label: {
                            row(session)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            StoryArchive.delete(sessions[index])
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.m) {
            Image(systemName: "book.pages")
                .font(.system(size: 40))
                .foregroundStyle(AppSurface.light.secondaryLabel)
            Text("还没有故事")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
            Text("写一条故事线，挑上角色，就能开场")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            Button {
                showSetup = true
            } label: {
                Text("开一个新故事")
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(Theme.deepGreen)
                    .padding(.horizontal, PhoneMetrics.Space.l)
                    .padding(.vertical, PhoneMetrics.Space.s)
                    .background(Capsule().fill(Theme.mint))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ session: StorySession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                Text(session.title)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                    .foregroundStyle(AppSurface.light.label)
                if session.isEnded {
                    Text("已结束")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                Spacer(minLength: 0)
                Text(TimeFormat.callTime(session.updatedAt))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Text(session.characterNames.joined(separator: "、"))
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            Text(session.premise)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .lineLimit(1)
        }
        .padding(.vertical, PhoneMetrics.Space.xs)
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
            .background(Theme.settingsBackground)
            .navigationTitle("新故事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开场") {
                        let player = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?
                            .first?.name ?? "我"
                        Task {
                            await viewModel.start(
                                title: title,
                                premise: premise,
                                uids: Array(selected),
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
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(AppSurface.light.secondaryLabel)
            TextEditor(text: $premise)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(PhoneMetrics.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(AppSurface.light.rowSurface)
                )
                .overlay(alignment: .topLeading) {
                    if premise.isEmpty {
                        Text("想玩什么？比如「放学后和她在天台看日落」")
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
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
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(AppSurface.light.secondaryLabel)
            TextField("给这个故事起个名", text: $title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .padding(PhoneMetrics.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(AppSurface.light.rowSurface)
                )
        }
    }

    // MARK: - 角色

    private var rosterBlock: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text("参与角色（1~3 个）")
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(AppSurface.light.secondaryLabel)

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
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .lineLimit(1)
                        .foregroundStyle(isSelected(item.id) ? Theme.deepGreen : AppSurface.light.label)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(isSelected(item.id) ? Theme.mint : AppSurface.light.rowSurface)
                        )
                        .overlay {
                            Capsule().strokeBorder(Theme.separator, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
