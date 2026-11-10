import Foundation
import Observation
import SwiftData

/// 一局文游的状态机。
///
/// 流程：填故事线 → 模型起标题并挑角色 → 逐轮推进（模型每轮给 2~3 个选项，
/// 也可以自由输入行动）→ 结束时按记忆模式把剧情回写进参与角色的记忆。
/// 存档整体走 `StoryArchive`，SwiftData 只在回写记忆时碰。
@Observable
@MainActor
final class StoryGameViewModel {
    private(set) var isStreaming = false
    private(set) var streamingText = ""
    private(set) var errorText: String?

    /// 开局阶段：模型挑完角色后回填，供确认页预选。
    private(set) var suggestedTitle = ""
    private(set) var suggestedUIDs: [UUID] = []
    private(set) var isPlanning = false

    var session: StorySession?

    /// 开局或续读时缓存的花名册。`turn` 组提示词要按 uid 找回人设，
    /// 从视图层一路传太吵，收在这里。
    private var rosterCache: [Companion] = []

    /// 可选角色：开局时要给模型一份花名册。
    static func roster(context: ModelContext) -> [Companion] {
        let all = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
        return all.sorted { $0.sortIndex < $1.sortIndex }
    }

    // MARK: - 开局

    /// 把故事线交给模型：起标题、从花名册里挑 1~3 个参与角色。
    /// 挑不出来（网络错、格式怪）就退回用户手选，不挡开局。
    func planStory(
        premise: String,
        roster: [Companion],
        settings: SettingsStore
    ) async {
        guard settings.isConfigured else {
            errorText = "还没填 API Key。去设置里填一个。"
            return
        }
        guard !premise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        errorText = nil
        isPlanning = true
        defer { isPlanning = false }

        let list = roster
            .map { "- \($0.name)：\($0.persona.prefix(80))" }
            .joined(separator: "\n")
        let system = """
        你在为一局文字游戏做开场准备。玩家想要的故事线：
        \(premise)

        可选角色（全部都是玩家世界里的角色）：
        \(list)

        只输出两行，严格遵守格式，不要多余的话：
        标题：（这个故事线的标题，不超过十个字）
        角色：（挑 1 到 3 个最适合这条故事线的角色名，用、分隔，只写名字）
        """

        let request = [ChatMessage(role: .system, text: system)]
        let client = OpenAICompatibleClient(config: settings.config)
        do {
            var reply = ""
            for try await piece in client.streamChat(request) {
                reply += piece
            }
            let visible = ReplyEnvelope.parse(reply).visibleText
            parsePlan(visible, roster: roster)
        } catch {
            errorText = "角色没挑成：\(error.localizedDescription)。可以自己选角色开局。"
        }
    }

    private func parsePlan(_ reply: String, roster: [Companion]) {
        var title = ""
        var names: [String] = []
        for line in reply.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("标题"), let idx = trimmed.firstIndex(where: { $0 == "：" || $0 == ":" }) {
                title = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            }
            if trimmed.hasPrefix("角色"), let idx = trimmed.firstIndex(where: { $0 == "：" || $0 == ":" }) {
                let body = String(trimmed[trimmed.index(after: idx)...])
                names = body
                    .split(whereSeparator: { "、，, ".contains($0) })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }

        suggestedTitle = String(title.prefix(12))
        let matched = names.compactMap { name in roster.first { $0.name == name }?.uid }
        suggestedUIDs = Array(matched.prefix(3))
    }

    /// 开局：先让模型写下第一幕。
    func start(
        title: String,
        premise: String,
        uids: [UUID],
        roster: [Companion],
        playerName: String,
        settings: SettingsStore
    ) async {
        let picked = uids.compactMap { uid in roster.first { $0.uid == uid } }
        guard !picked.isEmpty else {
            errorText = "至少要一个角色。"
            return
        }

        let fresh = StorySession(
            title: title.isEmpty ? "未命名故事" : title,
            premise: premise,
            characterUIDs: picked.map(\.uid),
            characterNames: picked.map(\.name),
            playerName: playerName
        )
        session = fresh
        rosterCache = roster
        await turn(choiceText: nil, settings: settings)
    }

    // MARK: - 推进

    /// 玩家选了一个选项（`choiceText` 非 nil）或自由输入了一段行动。
    func turn(choiceText: String?, settings: SettingsStore) async {
        guard var current = session, !current.isEnded else { return }
        guard settings.isConfigured else {
            errorText = "还没填 API Key。去设置里填一个。"
            return
        }
        guard !isStreaming else { return }
        errorText = nil

        if let choiceText {
            let text = choiceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            current.lines.append(
                StoryLine(speaker: current.playerName, text: text, isNarration: false)
            )
            current.options = []
            // 分支变量从这一步开始攒。存的是选择原文，分数由原文现算。
            current.registerChoice(text)
        }

        isStreaming = true
        streamingText = ""
        defer {
            isStreaming = false
            streamingText = ""
        }

        let request = buildRequest(session: current)
        let client = OpenAICompatibleClient(config: settings.config)
        do {
            for try await piece in client.streamChat(request) {
                streamingText += piece
            }

            let envelope = ReplyEnvelope.parse(streamingText)
            let reply = envelope.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                errorText = "模型一个字都没返回。可能是余额不足。"
                return
            }

            applyReply(reply, to: &current)
            session = current
            StoryArchive.save(current)
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// 回复拆行落档；选项标记抠出来变成按钮，不进正文。
    private func applyReply(_ reply: String, to session: inout StorySession) {
        let (stripped, options) = stripOptions(reply)
        session.options = options

        for line in ReplyParser.parseGroup(stripped) {
            session.lines.append(
                StoryLine(speaker: line.speaker, text: line.text, isNarration: line.isNarration)
            )
        }

        // 滚动摘要：最新一段顶掉最老的一段，控制提示词长度。
        let tail = stripped.replacingOccurrences(of: "\n", with: " ")
        session.summary = (session.summary + " " + String(tail.suffix(160)))
        if session.summary.count > 480 {
            session.summary = String(session.summary.suffix(480))
        }
        session.updatedAt = Date()
    }

    /// `[选项:A|B|C]` → 选项数组，标记从正文里移除。纯函数，不碰状态。
    private func stripOptions(_ reply: String) -> (text: String, options: [String]) {
        var collected: [String] = []
        let pattern = "\\[(选项|選項)\\s*[:：]\\s*([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (reply, [])
        }
        let range = NSRange(reply.startIndex..., in: reply)
        for match in regex.matches(in: reply, range: range) {
            guard let body = Range(match.range(at: 2), in: reply) else { continue }
            collected = reply[body]
                .split(whereSeparator: { $0 == "|" || $0 == "｜" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let text = regex.stringByReplacingMatches(in: reply, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, collected)
    }

    /// 玩家一路攒下来的倾向，翻译成一句给主持人的指示。
    ///
    /// 只给方向不给结局：写死「最后他走了」，故事就成了流程图；
    /// 让它自然往那个方向偏，结局才像是玩家自己走出来的。
    private func branchHint(_ session: StorySession) -> String {
        guard let branch = session.dominantBranch else { return "" }
        let tally = session.score(of: branch)
        return "玩家到目前为止一直偏向「\(branch.label)」（这一路已经有 \(tally) 次选择落在这一档）。接下来的情节可以往这个方向偏，但不要替玩家宣布结果。"
    }

    private func buildRequest(session: StorySession) -> [ChatMessage] {
        let personas = session.characterUIDs
            .compactMap { uid in rosterCache.first { $0.uid == uid } }
            .map { "- \($0.name)：\($0.persona.prefix(300))" }
            .joined(separator: "\n")

        let system = """
        你在主持一场文字游戏（文游）。玩家叫「\(session.playerName)」。
        故事线：\(session.premise)
        参与角色（必须严格遵守他们的人设）：
        \(personas)

        规则：
        - 用括号段落写旁白（场景、动作、氛围），用「名字：台词」让角色说话。
        - 每轮推进一段剧情，长度控制在三到五段，不要一次写完整个故事。
        - 结尾给 2 到 3 个行动选项，放在最后一行，严格用这个格式：[选项:A|B|C]，每个选项不超过十五个字。
        - 不要替玩家决定行动；玩家可能不选选项、自己输入行动，照常演绎。
        - 剧情走向尊重玩家的选择，不要强行拉回预设。
        \(branchHint(session))
        \(session.summary.isEmpty ? "" : "\n此前剧情摘要：\(session.summary)")
        """

        var request = [ChatMessage(role: .system, text: system)]

        let recent = session.lines.suffix(30)
        for line in recent {
            if line.isNarration {
                request.append(ChatMessage(role: .assistant, text: "（\(line.text)）"))
            } else if let speaker = line.speaker, speaker == session.playerName {
                request.append(ChatMessage(role: .user, text: line.text))
            } else {
                let name = line.speaker ?? "旁白"
                request.append(ChatMessage(role: .assistant, text: "\(name)：\(line.text)"))
            }
        }

        // 每轮都以用户消息收尾，流式接口要求最后一条不是 system。
        if request.last?.role != .user {
            request.append(ChatMessage(role: .user, text: "（继续）"))
        }
        return request
    }

    // MARK: - 结束与记忆回写

    /// 结束一局。`mode` 决定剧情以什么身份写进参与角色的记忆；
    /// `.hidden` 不写任何东西。
    func end(mode: StoryMemoryMode, context: ModelContext) {
        guard var current = session else { return }
        current.isEnded = true
        current.options = []
        current.updatedAt = Date()

        // 结局先算出来，下面写记忆要用。分支变量一路攒着，走到这里才有定论。
        // 不再额外问模型一次：再要一段「结局正文」会让同一件事被讲两遍，
        // 一个标签加一句收束就够了。
        let ending = current.dominantBranch
        if let ending {
            current.endingLabel = ending.endingTitle
        }

        if mode != .hidden, let tail = memoryTail(current) {
            // 按 uid 找角色，不碰 `characterNames`：它和 `characterUIDs` 是两个
            // 平行数组，比它短一次就下标越界。存档是用户能导出再导回来的，
            // 这里不能假定两边等长。
            for uid in current.characterUIDs {
                guard let character = try? context.fetch(
                    FetchDescriptor<Companion>(predicate: #Predicate { $0.uid == uid })
                ).first else { continue }
                let entry: String
                switch mode {
                case .asReality:
                    entry = "【共同经历】你和\(current.playerName)真实地一起经历了「\(current.title)」：\(tail)。这是真实发生的事。"
                case .asGame:
                    entry = "【文游回忆】你和\(current.playerName)一起玩了文游「\(current.title)」（你知道这是游戏）：\(tail)。"
                case .hidden:
                    continue
                }
                let endingNote = ending.map { "。最后是「\($0.endingTitle)」：\($0.endingLine)" } ?? ""
                character.memorySummary = (character.memorySummary + "\n" + entry + endingNote)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                context.insert(character)
            }
            try? context.save()
        }

        session = current
        StoryArchive.save(current)
    }

    /// 记忆回写用的剧情尾巴：最近十行，压成一行。
    private func memoryTail(_ session: StorySession) -> String? {
        let recent = session.lines.suffix(10)
        guard !recent.isEmpty else { return nil }
        let text = recent
            .map { $0.isNarration ? $0.text : "\($0.speaker ?? "")说\($0.text)" }
            .joined(separator: "；")
        return String(text.suffix(200))
    }

    // MARK: - 存档操作

    func resume(_ session: StorySession, roster: [Companion]) {
        self.session = session
        rosterCache = roster
    }

    func close() {
        session = nil
        rosterCache = []
    }
}
