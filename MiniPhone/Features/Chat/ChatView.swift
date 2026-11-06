import SwiftUI
import SwiftData

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
    @State private var showDetail = false
    @State private var showCalls = false
    @State private var callKind: CallKind?
    /// 表情面板展开状态。输入栏那颗按钮切换它，不抢键盘。
    @State private var showStickers = false
    @FocusState private var isInputFocused: Bool

    init(character: Companion, settings: SettingsStore, onExit: @escaping () -> Void) {
        self.character = character
        self.settings = settings
        self.onExit = onExit
        let uid = character.uid
        _messages = Query(
            filter: #Predicate<StoredMessage> { $0.characterUID == uid && $0.channelRaw == "chat" },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .forward)]
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    private func isAsleep(at date: Date) -> Bool {
        CharacterClock.isAsleep(character, at: date)
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                transcript
                if showStickers {
                    stickerPanel
                }
                composer
            }
        }
        .onAppear {
            seedGreetingIfNeeded()
            // 截图流水线要拍表情面板，冷启动点不到那颗按钮，这里直接展开。
            if UserDefaults.standard.string(forKey: "previewState") == "chatStickers" {
                showStickers = true
            }
        }
        .sheet(isPresented: $showDetail) {
            CharacterDetailPage(
                character: character,
                world: WorldStore.shared,
                settings: settings,
                onRegenerate: {
                    showDetail = false
                    Task { await viewModel.regenerate(character: character, context: context, settings: settings) }
                },
                onClose: { showDetail = false }
            )
        }
        .sheet(isPresented: $showCalls) {
            CallScene(world: WorldStore.shared, onClose: { showCalls = false })
        }
        .fullScreenCover(item: $callKind) { kind in
            CallOverlay(
                character: character,
                kind: kind,
                settings: settings,
                model: viewModel,
                onEnd: { callKind = nil }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            GlassIconButton(symbol: "chevron.left", action: onExit)

            Button {
                showDetail = true
            } label: {
                HStack(spacing: 9) {
                    AvatarBubble(character: character, size: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(character.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(1)

                        TimelineView(.everyMinute) { context in
                            Text(subtitle(at: context.date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    isAsleep(at: context.date)
                                        ? Theme.cream.opacity(0.4)
                                        : Theme.mint.opacity(0.72)
                                )
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // 真机的信息 App 右上角就是这个位置放通话入口。
            // 点开是三项：语音、视频、通话记录——不再单独占一个桌面图标。
            GlassMenuButton(symbol: "phone.fill") {
                callMenuItems
            }
            GlassIconButton(symbol: "ellipsis") { showDetail = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var callMenuItems: some View {
        Button {
            callKind = .voice
        } label: {
            Label("语音通话", systemImage: "phone.fill")
        }

        Button {
            callKind = .video
        } label: {
            Label("视频通话", systemImage: "video.fill")
        }

        Divider()

        Button {
            showCalls = true
        } label: {
            Label("通话记录", systemImage: "clock.arrow.circlepath")
        }
    }

    private func subtitle(at date: Date) -> String {
        var parts: [String] = [character.preset.displayName]
        if character.isGroup { parts.append("群聊") }
        parts.append(isAsleep(at: date) ? "睡了" : "在的")
        return parts.joined(separator: " · ")
    }

    // MARK: - 对话区

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if messages.isEmpty && viewModel.displayedStreamingText.isEmpty {
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
                        .padding(.top, gapBefore(index))
                        .id(message.uid)
                    }

                    if viewModel.isStreaming {
                        MessageBubble(
                            text: viewModel.displayedStreamingText,
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

    /// 同一人连着说留 6，换个人说话再压 12 上去（合计 18）。
    ///
    /// 原来整列统一 12：自己连着发三段和对方回一句，视觉上是同一个密度，
    /// 一屏下来全糊成一片，读不出谁在接话。微信那种节奏靠的就是这个落差。
    private func gapBefore(_ index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        return messages[index - 1].role == messages[index].role ? 0 : 12
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
                    .foregroundStyle(Theme.warning)

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
            // 微信那套：输入框左边的加号里放通话。拨号不再占桌面一格。
            GlassMenuButton(symbol: "plus", size: 30) {
                callMenuItems
            }

            // 表情固定在输入栏里，不藏进菜单：发表情是高频动作，
            // 藏一层就没人用了。展开时收键盘，不然面板会被键盘顶到看不见。
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showStickers.toggle()
                }
                isInputFocused = false
            } label: {
                Image(systemName: showStickers ? "keyboard" : "face.smiling")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(showStickers ? Theme.mint : Theme.cream.opacity(0.72))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    // MARK: - 表情面板

    private var stickerPanel: some View {
        let items = StickerLibrary.shared.available(for: character)

        return Group {
            if items.isEmpty {
                Text("还没有表情。去设置 → 表情里加一些。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cream.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            Button {
                                sendSticker(item)
                            } label: {
                                StickerView(item: item, size: 54)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(height: 78)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 表情也是消息：落成一条 `[表情:名字]`，跟打字发出去走同一条链路，
    /// 这样记忆、重试、导出都不用为它单独开一条路。
    private func sendSticker(_ item: StickerItem) {
        guard !viewModel.isStreaming else { return }
        showStickers = false
        Task {
            await viewModel.send(
                "[表情:\(item.name)]",
                character: character,
                context: context,
                settings: settings
            )
        }
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
}
