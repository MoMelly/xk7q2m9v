import SwiftUI
import SwiftData

/// 直播间的运行状态。
///
/// 弹幕分两种来源：本地定时刷的路人弹幕（纯氛围），和角色的真回复（调 API）。
/// 观众数围绕基数缓慢漂移。整个 Task 循环跟着视图生命周期走，
/// 离开直播间自动停，不留后台任务。
@Observable
@MainActor
final class LiveRoomModel {
    struct Danmaku: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var text: String
        /// 角色发言：高亮一行。礼物：金色一行。
        var kind: Kind = .viewer
        enum Kind { case viewer, character, gift, mine }
    }

    private static let viewerNames = [
        "晚风", "芝士圈", "奶糖", "kiwi", "阿茶", "线上冲浪", "不吃香菜",
        "月亮邮递员", "半糖去冰", "蹲蹲子", "打工魂", "小笼包", "白噪音"
    ]

    private static let viewerLines = [
        "来了来了", "主播好可爱", "哈哈哈哈哈哈", "打卡", "666", "前面+1",
        "这背景音乐叫什么", "蹲一个后续", "爱了爱了", "状态好好啊", "新来的",
        "弹幕护体", "太强了吧", "求歌单", "今天就到这吗", "网速顶住"
    ]

    private static let giftNames = ["小心心", "棒棒糖", "奶茶", "烟花", "小花束"]

    private(set) var danmaku: [Danmaku] = []
    private(set) var viewers: Int
    private(set) var isThinking = false
    var draft = ""
    var errorText: String?

    private var pumpTask: Task<Void, Never>?
    private let room: LiveRoom
    private var character: Companion?

    init(room: LiveRoom) {
        self.room = room
        viewers = room.viewers
    }

    /// 角色房间要带 Companion 才能调 API；路人房间传 nil 就行。
    func start(character: Companion?, playerName: String) {
        self.character = character
        self.playerName = playerName
        guard pumpTask == nil else { return }

        // 进场先铺几条，别让房间空着等第一个定时器。
        for _ in 0..<4 {
            danmaku.append(makeViewerDanmaku())
        }
        pumpTask = Task { [weak self] in
            await self?.runPump()
        }
    }

    func stop() {
        pumpTask?.cancel()
        pumpTask = nil
    }

    private var playerName = "你"

    private func runPump() async {
        while !Task.isCancelled {
            let wait = UInt64(Double.random(in: 1.8...4.2) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: wait)
            guard !Task.isCancelled else { return }

            danmaku.append(makeViewerDanmaku())
            trim()
            // 观众数 ±2% 漂移。
            viewers = max(20, viewers + Int(Double(viewers) * Double.random(in: -0.02...0.02)))
        }
    }

    private func makeViewerDanmaku() -> Danmaku {
        let name = Self.viewerNames.randomElement() ?? "路人"
        let line = Self.viewerLines.randomElement() ?? "打卡"
        return Danmaku(name: name, text: line)
    }

    /// 弹幕列表只留最近 40 条，别让它无限涨。
    private func trim() {
        if danmaku.count > 40 {
            danmaku.removeFirst(danmaku.count - 40)
        }
    }

    // MARK: - 玩家动作

    /// 发一条弹幕。角色房间会等模型接话，路人房间只上屏。
    func send(_ raw: String, settings: SettingsStore) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        draft = ""
        errorText = nil
        danmaku.append(Danmaku(name: playerName, text: text, kind: .mine))
        trim()

        guard let character else { return }
        guard settings.isConfigured else {
            errorText = "没填 API Key，角色接不了话。"
            return
        }

        isThinking = true
        defer { isThinking = false }

        let system = """
        你在直播，是主播。你的人设：
        \(character.persona.prefix(300))

        观众「\(playerName)」刚发来弹幕或礼物，弹幕流最后几条是上下文。
        用一到两句话回应，像主播对镜头说话：口语化、可以接梗、可以招呼其他观众。
        不要旁白、不要括号动作、不要超过四十字。
        """

        var request = [ChatMessage(role: .system, text: system)]
        for item in danmaku.suffix(10) {
            let line: String
            switch item.kind {
            case .character: line = "你（主播）：\(item.text)"
            case .gift: line = "\(item.name) 送出了 \(item.text)"
            default: line = "\(item.name)：\(item.text)"
            }
            request.append(ChatMessage(role: .user, text: line))
        }
        request.append(ChatMessage(role: .user, text: "\(playerName)：\(text)"))

        let client = OpenAICompatibleClient(config: settings.config)
        do {
            var reply = ""
            for try await piece in client.streamChat(request) {
                reply += piece
            }
            let visible = ReplyEnvelope.parse(reply).visibleText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !visible.isEmpty else { return }

            // 回复可能带「名字：」前缀，去掉再上弹幕。
            let body = visible.contains("：")
                ? visible.components(separatedBy: "：").dropFirst().joined(separator: "：")
                : visible
            danmaku.append(Danmaku(name: room.anchorName, text: body, kind: .character))
            trim()
        } catch {
            errorText = "角色没接上话：\(error.localizedDescription)"
        }
    }

    /// 送礼物：本地一条金色弹幕，角色房间让主播谢一下。
    func sendGift(settings: SettingsStore) async {
        let gift = Self.giftNames.randomElement() ?? "小心心"
        danmaku.append(Danmaku(name: playerName, text: "送出了 \(gift)", kind: .gift))
        trim()
        await send("送你一个\(gift)", settings: settings)
    }
}

/// 直播间：满屏画面 + 弹幕流 + 输入栏。
///
/// 路人房间是纯氛围（本地弹幕），角色房间发弹幕会真的被接话。
struct LiveRoomPage: View {
    let room: LiveRoom
    let companions: [Companion]
    let settings: SettingsStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model: LiveRoomModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            MockPhoto(seed: room.seed)
                .ignoresSafeArea()
                .overlay {
                    // 上深下深中间透：保证顶栏和弹幕可读，画面主体不被压灰。
                    LinearGradient(
                        colors: [.black.opacity(0.45), .clear, .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                danmakuPanel
                inputBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let name = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first?.name ?? "你"
            let anchor = model ?? LiveRoomModel(room: room)
            anchor.start(character: room.characterUID.flatMap { uid in companions.first { $0.uid == uid } },
                         playerName: name)
            if model == nil { model = anchor }
        }
        .onDisappear {
            model?.stop()
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Button {
                model?.stop()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .buttonStyle(.plain)

            FeedAvatar(name: room.anchorName, isCharacter: room.isCharacter, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.anchorName)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                    Text("\(model?.viewers ?? room.viewers)")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                }
                .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 0)

            if room.isCharacter {
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.brand))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.s)
    }

    // MARK: - 弹幕

    private var danmakuPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model?.danmaku.suffix(9) ?? []) { item in
                danmakuRow(item)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if model?.isThinking == true {
                Text("\(room.anchorName) 正在打字…")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, PhoneMetrics.Space.m)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.25), value: model?.danmaku.count)
        .padding(.horizontal, PhoneMetrics.Space.s)
        .padding(.bottom, PhoneMetrics.Space.xs)
    }

    @ViewBuilder
    private func danmakuRow(_ item: LiveRoomModel.Danmaku) -> some View {
        let highlight = item.kind == .character
        let golden = item.kind == .gift

        HStack(alignment: .top, spacing: 6) {
            if highlight {
                FeedAvatar(name: item.name, isCharacter: true, size: 16)
            }
            Text(highlight || golden ? "\(item.name) \(item.text)" : "\(item.name)：\(item.text)")
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: highlight ? .semibold : .regular))
                .foregroundStyle(
                    highlight ? Theme.mint : golden ? Theme.cream : .white
                )
                .lineLimit(2)
        }
        .padding(.horizontal, PhoneMetrics.Space.s)
        .padding(.vertical, 4)
        .background(
            highlight
                ? RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                    .fill(.black.opacity(0.42))
                : nil
        )
    }

    // MARK: - 输入

    private var inputBar: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            HStack(spacing: PhoneMetrics.Space.s) {
                TextField("说点什么…", text: Binding(
                    get: { model?.draft ?? "" },
                    set: { model?.draft = $0 }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(.white)
                .lineLimit(1...3)
                .focused($isInputFocused)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)
                .background(
                    Capsule().fill(.white.opacity(0.16))
                )
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                }
                .onSubmit {
                    let text = model?.draft ?? ""
                    Task { await model?.send(text, settings: settings) }
                }

                Button {
                    Task { await model?.sendGift(settings: settings) }
                } label: {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.deepGreen)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.mint))
                }
                .buttonStyle(.plain)
                .disabled(model?.isThinking == true)

                Button {
                    let text = model?.draft ?? ""
                    Task { await model?.send(text, settings: settings) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.deepGreen)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.mint))
                }
                .buttonStyle(.plain)
                .disabled((model?.draft ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)

            if let error = model?.errorText {
                Text(error)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, PhoneMetrics.Space.s)
    }
}
