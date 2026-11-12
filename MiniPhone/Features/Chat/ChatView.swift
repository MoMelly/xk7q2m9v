import SwiftUI
import SwiftData
import UIKit

/// 和某个角色的对话页。
///
/// 真机的信息 App 没有导航栏层级感，只有一条居中的联系人标题，
/// 所以顶部用手搓的一行，不用 NavigationStack。
struct ChatView: View {
    let character: Companion
    let settings: SettingsStore
    var onExit: () -> Void

    @Environment(\.modelContext) var context
    // 这两个不写 `private`：消息行那几段判断拆到了 `ChatView+Row.swift`，
    // 同一类型的 extension 跨文件访问不到文件级私有成员。
    @Query var messages: [StoredMessage]
    /// 拍一拍要用名字：「小绿 拍了拍 陆沉 的脑门」。
    @Query(sort: \UserProfile.createdAt, order: .forward) var profiles: [UserProfile]

    @State var viewModel = ChatViewModel()
    @State var draft = ""
    @State private var showDetail = false
    @State private var showCalls = false
    @State private var showVoices = false
    /// 点了置顶条要滚到哪一条。滚完清空，不然回来还会再滚一次。
    @State private var pinnedTarget: UUID?
    @State private var callKind: CallKind?
    /// 表情面板展开状态。输入栏那颗按钮切换它，不抢键盘。
    @State var showStickers = false
    /// 发图面板。和表情面板互斥，同时开两个会把输入栏顶到看不见。
    @State var showPhotos = false
    /// 发红包的金额面板。
    @State var showPacket = false
    @FocusState var isInputFocused: Bool
    /// 输入栏的完整态开关。默认收成一条安静的提示条——页面上摆一个
    /// 等着打字的输入框，看上去就像对话正在进行到一半；点一下才醒。
    @State private var isComposerActive = false

    /// 正在引用的那条。发出去时带在消息上，发完清空。
    @State var quoting: StoredMessage?
    /// 正在改的那条。不为空时发送键改成「覆写」而不是「新增」。
    @State var editingTarget: StoredMessage?

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

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    /// 「回话」键亮不亮：攒了没被回的话、而且对方不在打字。
    private var canRequestReply: Bool {
        !viewModel.isStreaming && viewModel.hasPendingUserMessages(for: character)
    }

    /// 一起听的状态挂在播放器上：歌是这台手机放的，跟会话无关。
    private let player = PlayerService.shared

    private var isTogether: Bool { player.isTogether(with: character.uid) }

    /// 邀请/结束都不走网络。它只是把「这会儿跟谁一起听」记下来，
    /// 下一轮生成时若还在一起听，提示词才会带这首歌。
    private func toggleTogether() {
        Haptics.tap()
        if isTogether {
            player.endTogether()
        } else {
            player.invite(uid: character.uid, name: character.name)
        }
    }

    var body: some View {
        ZStack {
            ChatBackgroundView(settings: settings).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if !pinnedMessages.isEmpty {
                    ChatPinnedBar(
                        messages: pinnedMessages,
                        myName: myDisplayName,
                        onTap: { pinnedTarget = $0.uid },
                        onUnpin: { togglePin($0) }
                    )
                }

                if isTogether {
                    ChatTogetherBar(
                        partnerName: character.name,
                        trackTitle: player.track?.title,
                        isPlaying: player.isPlaying,
                        onEnd: { player.endTogether() }
                    )
                }

                transcript
                if showStickers {
                    ChatStickerPanel(character: character) { sendSticker($0) }
                }
                if showPhotos {
                    ChatPhotoPanel { sendPhoto($0) }
                }
                if let target = editingTarget {
                    ChatContextBar(
                        symbol: "pencil",
                        title: "正在改这一句",
                        detail: target.text,
                        onCancel: cancelEdit
                    )
                } else if let source = quoting {
                    ChatContextBar(
                        symbol: "quote.opening",
                        title: "引用 \(source.role == .user ? "我" : (source.speaker ?? character.name))",
                        detail: source.text,
                        onCancel: { quoting = nil }
                    )
                }
                composer
            }
        }
        .onAppear {
            seedGreetingIfNeeded()
            // 截图流水线要拍表情面板 / 角色详情 / 通话这些层，冷启动点不到按钮，
            // 这里按状态名直接打开。正常启动读不到这个键，一件都不会触发。
            switch UserDefaults.standard.string(forKey: "previewState") {
            case "chatStickers":
                showStickers = true
                isComposerActive = true
            case "chatDynamic":
                // 截图流水线拍动效背景这一档；正常启动读不到这个键。
                settings.chatBackgroundRaw = ChatBackgroundMode.dynamic.rawValue
            case "chatGlass":
                // 拍玻璃气泡两档深浅的对比，截图要能看出两侧不一样。
                settings.setChatBubble(.glass)
            case "chatPhoto":
                showPhotos = true
                isComposerActive = true
            case "charDetail", "board", "statePanel", "anonBox", "worldEntries", "groupDetail", "groupMemory":
                // board / statePanel / anonBox 是再往下压一层的页面，截图流水线
                // 没有手势可用，先把详情页打开，由它自己决定要不要直接落到那一层。
                // worldEntries 再深一级：详情 → 编辑器 → 世界书列表，逐层自己开。
                showDetail = true
            case "call":
                callKind = .voice
            case "chatTogether":
                // 拍「一起听」状态条。这一屏打开的是谁由外壳挑，
                // 邀请必须落在同一个人身上，所以放在这里而不是预置数据里。
                player.invite(uid: character.uid, name: character.name)
            case "redPacket":
                // 同理：这一屏打开的是谁由外壳挑，红包得挂在他身上才拍得到。
                seedPreviewPacket()
            default:
                break
            }
        }
        // 收键盘、关面板、发完消息之后都试一次躺回收起态。
        .onChange(of: isInputFocused) { _, _ in settleComposerIfNeeded() }
        .onChange(of: showStickers) { _, _ in settleComposerIfNeeded() }
        .onChange(of: showPhotos) { _, _ in settleComposerIfNeeded() }
        .onChange(of: draft) { _, _ in settleComposerIfNeeded() }
        .onChange(of: viewModel.isStreaming) { wasStreaming, isStreaming in
            settleComposerIfNeeded()
            // 一轮说完了才念。边流边念会一个字一个字往外蹦，听不清在说什么。
            guard wasStreaming, !isStreaming, settings.speakReplies else { return }
            guard let last = messages.last, last.role == .assistant, !last.text.isEmpty else { return }
            // 群聊按说话人取名，不然群里所有人共用一个声音。
            SpeechService.shared.speak(last.text, as: last.speaker ?? character.name)
        }
        .onChange(of: SpeechService.shared.transcript) { _, text in
            // 识别到一半就往输入框里填，说完直接发，不用再改一遍。
            guard SpeechService.shared.isListening, !text.isEmpty else { return }
            draft = text
        }
        .onDisappear {
            SpeechService.shared.stopSpeaking()
            SpeechService.shared.stopListening()
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
        .sheet(isPresented: $showVoices) {
            CharacterVoicesSheet(name: character.name) { showVoices = false }
        }
        .sheet(isPresented: $showPacket) {
            RedPacketSheet(
                onSend: { cents, note in sendPacket(cents: cents, note: note) },
                onCancel: { showPacket = false }
            )
            .presentationDetents([.height(470)])
            .presentationBackground(Theme.cardSurface)
            .presentationDragIndicator(.hidden)
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
        ChatHeaderBar(
            character: character,
            onBack: onExit,
            onPat: pat,
            onOpenDetail: { showDetail = true },
            onOpenVoices: { showVoices = true },
            onOpenPhotos: {
                showStickers = false
                showPhotos = true
            },
            onCall: { callKind = $0 },
            onCallHistory: { showCalls = true },
            togetherTitle: isTogether ? "结束一起听" : "一起听",
            onTogether: toggleTogether
        )
    }

    /// 置顶的取最新两条。撤回和拍一拍不该出现在这里——
    /// 一条被收回的话挂在顶上只会让人困惑。
    private var pinnedMessages: [StoredMessage] {
        Array(messages.filter { $0.isPinned && !$0.isRecalled && !$0.isPat }.suffix(2))
    }

    private func togglePin(_ message: StoredMessage) {
        message.isPinned.toggle()
        try? context.save()
    }

    // MARK: - 对话区

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if messages.isEmpty && viewModel.displayedStreamingText.isEmpty {
                        ChatEmptyState(isConfigured: settings.isConfigured)
                    }

                    ForEach(Array(messages.enumerated()), id: \.element.uid) { index, message in
                        if shouldShowTime(at: index) {
                            ChatTimeSeparator(date: message.createdAt)
                        }

                        if message.isPat {
                            ChatPatNotice(text: message.text)
                                .id(message.uid)
                        } else {
                            row(for: message)
                                .padding(.top, gapBefore(index))
                                .id(message.uid)
                        }
                    }

                    if viewModel.isStreaming {
                        HStack(alignment: .top, spacing: 8) {
                            if settings.showChatAvatar {
                                AvatarBubble(character: character, size: 30)
                                    .padding(.top, 2)
                            }

                            MessageBubble(
                                text: viewModel.displayedStreamingText,
                                isUser: false,
                                isNarration: false,
                                isStreaming: true
                            )
                        }
                        .id("streaming")
                    }

                    if let errorText = viewModel.errorText {
                        ChatErrorCard(text: errorText, onDismiss: { viewModel.clearError() })
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: pinnedTarget) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(new, anchor: .center)
                }
                pinnedTarget = nil
            }
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

    /// 一条气泡加上它的长按菜单。
    ///
    /// 菜单里的动作都只改这一条消息，不碰对话状态：
    /// 撤回留文本、编辑覆写、删除真删、复制进剪贴板。
    func bubble(for message: StoredMessage) -> some View {
        MessageBubble(
            text: message.text,
            isUser: message.role == .user,
            speaker: message.speaker,
            isNarration: message.isNarration,
            imageSeed: message.imageSeed,
            userStyle: settings.chatBubbleStyle,
            isRecalled: message.isRecalled,
            quoteSpeaker: message.quoteSpeaker,
            quoteText: message.quoteText,
            isEdited: message.editedAt != nil,
            packetCents: message.packetCents,
            packetNote: message.packetNote,
            packetOpened: message.packetOpened,
            onOpenPacket: { openPacket(message) }
        )
        .chatMessageMenu(
            for: message,
            canRecall: message.role == .user,
            onCopy: { UIPasteboard.general.string = message.text },
            onQuote: { beginQuote(message) },
            onEdit: { beginEdit(message) },
            onRecall: { recall(message) },
            onPin: { togglePin(message) },
            onDelete: { delete(message) }
        )
    }

    /// 双击头像拍的这一下。抖动一下再把那条事件落库，
    /// 手感是「拍到了」，而不是「界面闪了一下」。
    ///
    /// 群不响应：拍的是「这个人」，群没有后缀也没有「被拍到」的体感。
    private func pat() {
        guard !character.isGroup else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        viewModel.sendPat(character: character, myName: myDisplayName, context: context)
    }

    private func beginQuote(_ message: StoredMessage) {
        editingTarget = nil
        quoting = message
        isComposerActive = true
    }

    private func beginEdit(_ message: StoredMessage) {
        quoting = nil
        editingTarget = message
        draft = message.text
        isComposerActive = true
        isInputFocused = true
    }

    private func cancelEdit() {
        editingTarget = nil
        draft = ""
    }

    private func recall(_ message: StoredMessage) {
        message.isRecalled = true
        try? context.save()
    }

    private func delete(_ message: StoredMessage) {
        context.delete(message)
        try? context.save()
    }

    // MARK: - 输入条

    @ViewBuilder
    private var composer: some View {
        if isComposerActive {
            activeComposer
        } else {
            restingComposer
        }
    }

    /// 收起态：一条安静的提示条，没有按钮、没有光标。
    /// 页面上常驻一个等着打字的输入框，看上去就像对话进行到一半；
    /// 点一下才醒。整条可点，点完直接进完整输入态。
    private var restingComposer: some View {
        HStack {
            Text("点这里说话")
                .font(.system(size: 15))
                .foregroundStyle(Theme.cream.opacity(0.38))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .glassSurface(cornerRadius: 22)
        .contentShape(Rectangle())
        .onTapGesture(perform: activateComposer)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 说话键。说话时不收键盘也不弹面板，只是把识别到的字往输入框里填。
    private var activeComposer: some View {
        HStack(spacing: 10) {
            // 微信那套：输入框左边的加号里放通话。拨号不再占桌面一格。
            GlassMenuButton(symbol: "plus", size: 30) {
                ChatCallMenuItems(
                    onPhotos: {
                        showStickers = false
                        showPhotos = true
                    },
                    onCall: { callKind = $0 },
                    onHistory: { showCalls = true },
                    togetherTitle: isTogether ? "结束一起听" : "一起听",
                    onTogether: toggleTogether,
                    onPacket: { showPacket = true },
                    isGroup: character.isGroup
                )
            }

            // 表情固定在输入栏里，不藏进菜单：发表情是高频动作，
            // 藏一层就没人用了。展开时收键盘，不然面板会被键盘顶到看不见。
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showStickers.toggle()
                    showPhotos = false
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

            micButton

            TextField("说点什么", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.cream)
                .tint(Theme.mint)
                .lineLimit(1...4)
                .focused($isInputFocused)

            // 竖排输入框里回车就是换行，键盘不再挂发送——发不触发回复，
            // 回车职责只剩排版。发送键只落库，AI 由最右边那颗「回话」键请出来。
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

            Button {
                Task {
                    await viewModel.requestReply(
                        character: character,
                        context: context,
                        settings: settings
                    )
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(canRequestReply ? Theme.mint : Theme.mint.opacity(0.22))
                        .frame(width: 34, height: 34)

                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.deepGreen)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canRequestReply)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: 26)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func activateComposer() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isComposerActive = true
        }
        isInputFocused = true
    }

    /// 什么时候可以躺回去：没在打字、面板没开着、也没在等回复。
    /// 流式中保持完整态——发送键上挂着进度圈，收起就看不见了。
    private func settleComposerIfNeeded() {
        let panelOpen = showStickers || showPhotos
        if !isInputFocused && draft.isEmpty && !panelOpen && !viewModel.isStreaming {
            withAnimation(.easeInOut(duration: 0.18)) {
                isComposerActive = false
            }
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
