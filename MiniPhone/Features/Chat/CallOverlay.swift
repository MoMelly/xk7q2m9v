import SwiftUI
import SwiftData

/// 通话类型。
enum CallKind: String, Identifiable, CaseIterable {
    case voice
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice: return "语音通话"
        case .video: return "视频通话"
        }
    }

    var symbol: String {
        switch self {
        case .voice: return "phone.fill"
        case .video: return "video.fill"
        }
    }
}

/// 通话界面。
///
/// 语音和视频都是文字模拟：没有真的录音和摄像头，界面按真机通话做，
/// 内容是模型写的台词，所以「说话」还是靠打字。
///
/// 这一层不自己存消息：走的是同一个 `ChatViewModel`，说过的每一句都落进
/// 这段会话，挂掉之后在聊天记录里能翻到，角色的记忆也是同一份。
struct CallOverlay: View {
    let character: Companion
    let kind: CallKind
    let settings: SettingsStore
    let model: ChatViewModel
    var onEnd: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var messages: [StoredMessage]

    @State private var startedAt = Date()
    @State private var draft = ""
    @State private var didStart = false
    @State private var pulse = false
    /// 通话里也能发表情。跟聊天页同一个入口位置，学一次就够。
    @State private var showStickers = false
    @FocusState private var isTyping: Bool

    init(
        character: Companion,
        kind: CallKind,
        settings: SettingsStore,
        model: ChatViewModel,
        onEnd: @escaping () -> Void
    ) {
        self.character = character
        self.kind = kind
        self.settings = settings
        self.model = model
        self.onEnd = onEnd

        let uid = character.uid
        _messages = Query(
            filter: #Predicate<StoredMessage> { $0.characterUID == uid && $0.channelRaw == "chat" },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .forward)]
        )
    }

    /// 只显示拨通之后说的话。之前的聊天记录不进通话界面。
    private var lines: [StoredMessage] {
        messages.filter { $0.createdAt >= startedAt }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deepGreen, Theme.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                portrait
                transcript
                controls
            }
        }
        .onAppear(perform: start)
        .statusBarHidden(true)
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(spacing: 6) {
            Text(character.name)
                .font(Theme.serif(26, weight: .medium))
                .foregroundStyle(Theme.cream)

            HStack(spacing: 6) {
                Circle()
                    .fill(model.isStreaming ? Theme.mint : Theme.mint.opacity(0.5))
                    .frame(width: 5, height: 5)

                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(statusText(at: context.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mint.opacity(0.8))
                }
            }
        }
        .padding(.top, 34)
    }

    private func statusText(at date: Date) -> String {
        if model.isStreaming { return "对方正在说话" }
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%@ %02d:%02d", kind.title, seconds / 60, seconds % 60)
    }

    // MARK: - 画面

    @ViewBuilder
    private var portrait: some View {
        if kind == .video {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.retroGreen.opacity(0.55), Theme.ink.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 10) {
                    AvatarBubble(character: character, size: 96)

                    Text("视频已接通")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.cream.opacity(0.55))
                }
            }
            .frame(height: 230)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)
        } else {
            ZStack {
                Circle()
                    .stroke(Theme.mint.opacity(0.28), lineWidth: 1)
                    .frame(width: 148, height: 148)
                    .scaleEffect(pulse ? 1.18 : 0.96)
                    .opacity(pulse ? 0 : 0.8)

                AvatarBubble(character: character, size: 112)
            }
            .frame(height: 170)
            .padding(.top, 18)
        }
    }

    // MARK: - 台词

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if lines.isEmpty && model.displayedStreamingText.isEmpty {
                        Text("接通了，等对方开口。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.cream.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }

                    ForEach(lines) { message in
                        line(
                            speaker: message.role == .user ? "你" : character.name,
                            text: message.text,
                            isUser: message.role == .user
                        )
                        .id(message.uid)
                    }

                    if !model.displayedStreamingText.isEmpty {
                        line(speaker: character.name, text: model.displayedStreamingText, isUser: false)
                            .id("streaming-line")
                    }

                    if let errorText = model.errorText {
                        Text(errorText)
                            .font(.system(size: 11).monospaced())
                            .foregroundStyle(Theme.warning)
                            .padding(.top, 4)
                    }

                    Color.clear.frame(height: 1).id("call-bottom")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .onChange(of: lines.count) { _, _ in
                proxy.scrollTo("call-bottom", anchor: .bottom)
            }
            .onChange(of: model.streamingText) { _, _ in
                proxy.scrollTo("call-bottom", anchor: .bottom)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func line(speaker: String, text: String, isUser: Bool) -> some View {
        let parsed = StickerTextParser.parse(text)

        return HStack(alignment: .top, spacing: 8) {
            Text(speaker)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isUser ? Theme.mint.opacity(0.85) : Theme.cream.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                if !parsed.body.isEmpty {
                    Text(parsed.body)
                        .font(.system(size: 14))
                        .foregroundStyle(isUser ? Theme.cream.opacity(0.95) : Theme.cream)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(parsed.names.enumerated()), id: \.offset) { _, name in
                    if let item = StickerLibrary.shared.item(named: name) {
                        // 通话里的表情比聊天页小一号：整屏是暗的，
                        // 一张 112 的图会把正在说的话挤出去。
                        StickerView(item: item, size: 76)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - 操作

    private var controls: some View {
        VStack(spacing: 16) {
            if showStickers {
                callStickerPanel
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showStickers.toggle()
                    }
                    isTyping = false
                } label: {
                    Image(systemName: showStickers ? "keyboard" : "face.smiling")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(showStickers ? Theme.deepGreen : Theme.cream.opacity(0.75))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(showStickers ? Theme.mint : .white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)

                TextField("打字模拟说话", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.cream)
                    .tint(Theme.mint)
                    .focused($isTyping)
                    .submitLabel(.send)
                    .onSubmit(sendLine)
                    .padding(.horizontal, 14)
                    .frame(height: 38)

                    .background(
                        Capsule().fill(.white.opacity(0.10))
                    )

                Button(action: sendLine) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.deepGreen)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(canSend ? Theme.mint : Theme.mint.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 20)

            Button {
                onEnd()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Theme.IconTint.pink))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 28)
        .padding(.top, 8)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isStreaming
    }

    // MARK: - 表情面板

    private var callStickerPanel: some View {
        let items = StickerLibrary.shared.available(for: character)

        return Group {
            if items.isEmpty {
                Text("还没有表情。去设置 → 表情里加一些。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cream.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            Button {
                                sendSticker(item)
                            } label: {
                                StickerView(item: item, size: 46)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 62)
        .transition(.opacity)
    }

    // MARK: - 行为

    private func start() {
        guard !didStart else { return }
        didStart = true
        startedAt = Date()

        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            pulse = true
        }

        Task {
            await model.beginCall(character: character, context: context, settings: settings)
        }
    }

    private func sendLine() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task {
            await model.send(
                text,
                character: character,
                context: context,
                settings: settings,
                callMode: true
            )
        }
    }

    /// 表情跟打字走同一条链路，通话里发的也能在聊天记录里翻到。
    private func sendSticker(_ item: StickerItem) {
        guard !model.isStreaming else { return }
        showStickers = false
        Task {
            await model.send(
                "[表情:\(item.name)]",
                character: character,
                context: context,
                settings: settings,
                callMode: true
            )
        }
    }
}
