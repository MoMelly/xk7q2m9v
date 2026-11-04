import SwiftUI
import SwiftData

/// 「信息」App 的会话列表。
///
/// 每个角色一个会话，像真机的信息列表那样排：头像、名字、最后一句、时间。
/// 不显示未读数——这个 App 里没有「别人给你发消息」，只有你在不在。
struct ConversationListView: View {
    let settings: SettingsStore
    var onExit: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Companion.sortIndex), SortDescriptor(\Companion.createdAt)])
    private var characters: [Companion]

    @State private var opened: Companion?
    @State private var showCreator = false
    @State private var pendingDelete: Companion?

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

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
                    context.delete(target)
                    try? context.save()
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - 列表

    private var listLayer: some View {
        VStack(spacing: 0) {
            header

            if characters.isEmpty {
                emptyState
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(characters) { character in
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

    private var header: some View {
        HStack(spacing: 10) {
            GlassIconButton(symbol: "chevron.left", action: onExit)

            ScreenTitle(
                title: "信息",
                detail: characters.isEmpty ? "还没有角色" : "\(characters.count) 个角色"
            )

            Spacer(minLength: 0)

            GlassIconButton(symbol: "plus") { showCreator = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

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
