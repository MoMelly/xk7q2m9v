import SwiftUI
import SwiftData
import Combine

/// 和某个角色的对话页。
///
/// 真机的信息 App 没有导航栏层级感，只有一条居中的联系人标题，
/// 所以顶部用手搓的一行，不用 NavigationStack。
struct ChatView: View {
    let character: Companion
    let settings: SettingsStore
    var onExit: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var messages: [StoredMessage]

    @State private var viewModel = ChatViewModel()
    @State private var draft = ""
    @State private var showEditor = false
    @State private var showActions = false
    @FocusState private var isInputFocused: Bool
    @State private var now = Date()

    init(character: Companion, settings: SettingsStore, onExit: @escaping () -> Void) {
        self.character = character
        self.settings = settings
        self.onExit = onExit
        let uid = character.uid
        _messages = Query(
            filter: #Predicate<StoredMessage> { $0.characterUID == uid },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .forward)]
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    private var isAsleep: Bool {
        CharacterClock.isAsleep(character, at: now)
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                transcript
                composer
            }
        }
        .onAppear { seedGreetingIfNeeded() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
        .sheet(isPresented: $showEditor) {
            CharacterEditorView(character: character, onFinish: { showEditor = false })
        }
        .confirmationDialog("这次对话", isPresented: $showActions, titleVisibility: .visible) {
            Button("重新生成最后一条") {
                Task { await viewModel.regenerate(character: character, context: context, settings: settings) }
            }
            Button("清空对话记录", role: .destructive) {
                clearHistory()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 17)

            Button {
                showEditor = true
            } label: {
                HStack(spacing: 9) {
                    AvatarBubble(character: character, size: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(character.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                isAsleep ? Theme.cream.opacity(0.4) : Theme.mint.opacity(0.72)
                            )
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                showActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 17)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var subtitle: String {
        var parts: [String] = [character.preset.displayName]
        if character.isGroup { parts.append("群聊") }
        parts.append(isAsleep ? "睡了" : "在的")
        return parts.joined(separator: " · ")
    }

    // MARK: - 对话区

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty && viewModel.streamingText.isEmpty {
                        emptyState
                    }

                    ForEach(Array(messages.enumerated()), id: \.element.uid) { index, message in
                        if shouldShowTime(at: index) {
                            timeSeparator(message.createdAt)
                        }

                        MessageBubble(
                            text: message.text,
                            isUser: message.role == .user,
                            speaker: message.speaker,
                            isNarration: message.isNarration
                        )
                        .id(message.uid)
                    }

                    if viewModel.isStreaming {
                        MessageBubble(
                            text: viewModel.streamingText,
                            isUser: false,
                            isNarration: false,
                            isStreaming: true
                        )
                        .id("streaming")
                    }

                    if let errorText = viewModel.errorText {
                        errorCard(errorText)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    /// 两条消息间隔超过 30 分钟才插时间，否则满屏都是时间戳。
    private func shouldShowTime(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = messages[index - 1].createdAt
        let current = messages[index].createdAt
        return current.timeIntervalSince(previous) > 60 * 30
    }

    private func timeSeparator(_ date: Date) -> some View {
        Text(CharacterClock.separatorText(date))
            .font(.system(size: 10, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Theme.cream.opacity(0.36))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没说话")
                .font(Theme.serif(19, weight: .medium))
                .foregroundStyle(Theme.cream)

            Text(settings.isConfigured
                 ? "直接打字就行。它会按自己的人设和作息回你。"
                 : "先去设置填一个 API Key，不然它没法回话。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mint.opacity(0.7))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 18)
        .padding(.top, 8)
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("出错了")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.55))

                Spacer(minLength: 0)

                Button("知道了") { viewModel.clearError() }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mint.opacity(0.8))
                    .buttonStyle(.plain)
            }

            Text(text)
                .font(.system(size: 12).monospaced())
                .foregroundStyle(Theme.cream.opacity(0.9))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
    }

    // MARK: - 输入条

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("说点什么", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.cream)
                .tint(Theme.mint)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit(submit)

            Button(action: submit) {
                ZStack {
                    Circle()
                        .fill(canSend ? Theme.mint : Theme.mint.opacity(0.22))
                        .frame(width: 34, height: 34)

                    if viewModel.isStreaming {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.deepGreen)
                            .scaleEffect(0.68)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.deepGreen)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: 26)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func submit() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task {
            await viewModel.send(text, character: character, context: context, settings: settings)
        }
    }

    // MARK: - 数据

    /// 第一次打开时把开场白落成一条消息。
    /// 判空用关系而不是 `@Query`，因为后者第一帧还没加载完，会重复插入。
    private func seedGreetingIfNeeded() {
        guard character.messages.isEmpty else { return }
        let greeting = character.greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !greeting.isEmpty else { return }

        let message = StoredMessage(characterUID: character.uid, role: .assistant, text: greeting)
        message.character = character
        context.insert(message)
        try? context.save()
    }

    private func clearHistory() {
        for message in character.messages {
            context.delete(message)
        }
        character.memorySummary = ""
        character.memoryCursor = nil
        try? context.save()
        seedGreetingIfNeeded()
    }
}
