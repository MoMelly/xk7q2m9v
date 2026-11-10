import Foundation
import Observation
import SwiftData

/// 一次对话的状态机。
///
/// 只负责「发出去、流回来、落库、压缩记忆」这四件事，界面完全由 `@Query` 驱动，
/// 所以杀掉进程重开之后看到的东西和退出前一致。
@Observable
@MainActor
final class ChatViewModel {
    /// 正在流式生成的内容。落库之前它只活在内存里。
    private(set) var streamingText: String = ""
    private(set) var isStreaming = false
    private(set) var errorText: String?

    /// 上屏用的正文。按次计费时回复尾部带一段状态块，不能让用户看见。
    var displayedStreamingText: String {
        ReplyEnvelope.streamingVisible(streamingText)
    }

    // MARK: - 发送

    /// 把一条消息落库。默认不触发回复——真人聊天是连发好几句才等对方开口，
    /// 一句一答是机器人。要对方说话，走 `requestReply`；通话里除外，
    /// 通话的每一句都是当场接的，`callMode` 传 true 保持一句一答。
    func send(
        _ raw: String,
        character: Companion,
        context: ModelContext,
        settings: SettingsStore,
        callMode: Bool = false,
        imageSeed: Int = 0,
        quoteSpeaker: String = "",
        quoteText: String = "",
        packetCents: Int = 0,
        packetNote: String = ""
    ) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 发图可以一个字都不写，所以空文本在有图时也算一条消息。
        guard !text.isEmpty || imageSeed > 0, !isStreaming else { return }

        let userMessage = StoredMessage(
            characterUID: character.uid,
            role: .user,
            text: text,
            imageSeed: imageSeed
        )
        userMessage.quoteSpeaker = quoteSpeaker
        userMessage.quoteText = quoteText
        userMessage.packetCents = packetCents
        userMessage.packetNote = packetNote
        userMessage.character = character
        context.insert(userMessage)
        character.lastMessageAt = Date()
        save(context)
        // 火花记的是「今天我跟这个角色说过话」。别人那边不记。
        // 同一步把主屏/锁屏的「主角」换成他：刚跟谁说完话，主页就该显示谁的状态。
        WorldStore.shared.primaryName = character.name
        WorldStore.shared.markCoupleDay(fromMe: true, partner: character.name)

        guard callMode else { return }
        await generateReply(
            for: character,
            context: context,
            settings: settings,
            callMode: true
        )
    }

    /// 我拍了一下对方。
    ///
    /// 拍一拍是事件，不是一句「话」：落成一条 `isPat` 消息，界面上居中显示一行小字，
    /// 气泡那套样式一概不套。它照常留在历史里，所以模型也知道刚才被拍了一下。
    func sendPat(character: Companion, myName: String, context: ModelContext) {
        let suffix = character.patSuffix.isEmpty ? "的肩膀" : character.patSuffix
        let line = "\(myName) 拍了拍 \(character.name)\(suffix)"

        let message = StoredMessage(characterUID: character.uid, role: .user, text: line)
        message.isPat = true
        message.character = character
        context.insert(message)
        character.lastMessageAt = Date()
        save(context)
    }

    /// 攒下的话等够了吗：最后一条是用户发的（或者还没聊过），就该对方接了。
    /// 界面拿它点亮「回话」键；对方回过之后键就熄掉。
    func hasPendingUserMessages(for character: Companion) -> Bool {
        let last = character.messages
            .filter { $0.channel == .chat }
            .sorted { $0.createdAt < $1.createdAt }
            .last
        return last?.role != .assistant
    }

    /// 手动触发回复。攒了没发的几句由这里一起带出去，
    /// 不需要再传一段文本——上下文取的就是消息流本身。
    func requestReply(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        guard settings.isConfigured else {
            errorText = "还没填 API Key。点右上角齿轮填一个。"
            return
        }
        guard !isStreaming, hasPendingUserMessages(for: character) else { return }
        errorText = nil
        await generateReply(for: character, context: context, settings: settings, callMode: false)
    }

    /// 拨通之后让对方先开口。
    ///
    /// 电话和消息不一样：不会等你先发一句「在吗」。这里不插用户的假消息，
    /// 直接走一次生成，模型看到的最后一条还是之前聊到的地方。
    func beginCall(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        guard settings.isConfigured else {
            errorText = "还没填 API Key。点右上角齿轮填一个。"
            return
        }
        guard !isStreaming else { return }
        errorText = nil
        await generateReply(for: character, context: context, settings: settings, callMode: true)
    }

    /// 重新生成最后一条回复：先删掉最后一条助手消息，再走一遍生成。
    func regenerate(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        guard !isStreaming else { return }
        let sorted = character.messages
            .filter { $0.channel == .chat }
            .sorted { $0.createdAt < $1.createdAt }
        guard let last = sorted.last, last.role == .assistant else { return }

        context.delete(last)
        save(context)
        await generateReply(for: character, context: context, settings: settings, callMode: false)
    }

    private func generateReply(
        for character: Companion,
        context: ModelContext,
        settings: SettingsStore,
        callMode: Bool = false
    ) async {
        isStreaming = true
        streamingText = ""
        defer {
            isStreaming = false
            streamingText = ""
        }

        let plan = settings.generationPlan
        let world = WorldStore.shared
        let names = relatedNames(for: character)

        // 群成员表每次进群聊都同步一次：单聊时要靠它反查「他在哪些群里」，
        // 成员被改名或删掉之后，留着旧名字会让已经退群的人继续收到群记忆。
        if character.isGroup {
            world.syncGroup(named: character.name, members: names)
        }

        // 只取主聊天。西瓜皮的私信和转帖是另一条线，混进来之后模型会
        // 对着「刚从西瓜皮转来的那条帖子」继续往下聊，而且和
        // `hasPendingUserMessages`、`regenerate` 的口径对不上。
        let history = Array(
            character.messages
                .filter { $0.channel == .chat }
                .sorted { $0.createdAt < $1.createdAt }
                .suffix(plan.contextWindow)
        )

        let trigger = history
            .filter { $0.role == .user }
            .suffix(3)
            .map { $0.text }
            .joined(separator: "\n")

        let allEntries = (try? context.fetch(FetchDescriptor<WorldEntry>())) ?? []

        // 这个会话用哪个身份。角色记得的事不跟着换，换的只是他以为在跟谁说话。
        let identity = UserProfileBook
            .resolve(uid: character.personaUID, in: context)
            .map { profile in
                UserIdentity(
                    name: profile.name,
                    signature: profile.signature,
                    bio: profile.bio,
                    tags: profile.tags,
                    statusText: profile.statusText,
                    statusStickerName: profile.statusStickerName
                )
            }

        // 日历只在角色被允许读的时候才去取。默认关，关着就连查都不查。
        let calendarLines = character.canReadCalendar
            ? UserCalendarBridge.upcomingLines()
            : []

        // 一起听：只有真的邀请了这个角色、而且这会儿在放，才把歌带进提示词。
        // 一个人听歌不该让他知道；跟别人一起听，这个人更不该知道。
        let player = PlayerService.shared
        let listeningNow = player.isTogether(with: character.uid) && player.isPlaying
            ? player.track
            : nil

        // 他今天的时间轴要有，提示词里那块「今天的安排」才不是空的。
        // 生成是本地算的，不花接口调用；同一天只会落一份。
        world.ensureCharacterDay(
            named: character.name,
            wakeHour: character.wakeHour,
            sleepHour: character.sleepHour,
            replies: character.messages.filter { $0.role == .assistant }.count
        )

        let worldContext = world.context(
            for: names,
            deviceLines: DeviceSnapshot.lines(allowPhoneLookups: settings.allowPhoneLookups),
            calendarLines: calendarLines,
            focus: trigger,
            listeningNow: listeningNow
        )
        if !worldContext.voices.isEmpty {
            world.markReferenced(worldContext.voices)
        }

        // 刷新判定放在发请求之前：判定结果要进提示词，模型才知道这一轮带不带页面内容。
        let recentTitles = world.state.feed
            .sorted { $0.postedAt > $1.postedAt }
            .prefix(3)
            .map(\.title)
        let refresh = RefreshEngine.request(
            plan: plan,
            state: world.state,
            rules: settings.refreshRules,
            interval: settings.refreshInterval,
            recentTitles: Array(recentTitles),
            roll: { Double.random(in: 0..<1) }
        )

        let system = PromptBuilder.systemPrompt(
            character: character,
            worldEntries: allEntries,
            triggerText: trigger,
            lastMessageAt: history.dropLast().last?.createdAt,
            worldContext: worldContext,
            metaBlockRequired: plan.mergesSideEffects,
            refresh: refresh,
            callMode: callMode,
            userIdentity: identity,
            feedActivityLines: PromptBuilder.feedActivityLines(
                state: world.state,
                characterName: character.name
            ),
            stickerNames: StickerLibrary.shared.names(for: character),
            groupMates: groupMates(for: character, context: context)
        )

        var request: [ChatMessage] = [ChatMessage(role: .system, text: system)]
        // 群聊历史逐条带说话人，不然模型分不清上一位是谁。
        request.append(contentsOf: history.map { $0.asChatMessage(grouped: character.isGroup) })

        let client = OpenAICompatibleClient(config: settings.config)

        do {
            for try await piece in client.streamChat(request) {
                streamingText += piece
            }

            let envelope = ReplyEnvelope.parse(streamingText)
            // 原文先记下来再看能不能用：解析失败的时候，这份是唯一的线索。
            RawReplyLog.shared.append(
                characterName: character.name,
                model: settings.model,
                raw: streamingText,
                envelope: envelope
            )
            let reply = envelope.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                errorText = "模型一个字都没返回。可能是余额不足，或者这个模型不支持流式。"
                return
            }

            persist(
                reply,
                meta: envelope.meta,
                names: names,
                plan: plan,
                refresh: refresh,
                for: character,
                context: context,
                settings: settings
            )
        } catch {
            errorText = error.localizedDescription
            AppLog.ui.error("生成失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 落库

    private func persist(
        _ reply: String,
        meta: ReplyEnvelope.Meta?,
        names: [String],
        plan: GenerationPlan,
        refresh: RefreshRequest?,
        for character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) {
        let lines = character.isGroup
            ? ReplyParser.parseGroup(reply)
            : ReplyParser.parseSingle(reply)

        var lastText = reply
        var offset = 0
        for line in lines {
            // 一句话里可能挂着图：文字留给第一张，后面每张单独起一条，
            // 这样一张图一个气泡，不会挤成一条又长又乱的消息。
            let parsed = PhotoTextParser.parse(line.text)
            let bodies: [(text: String, seed: Int)]

            if parsed.notes.isEmpty {
                bodies = [(text: parsed.body, seed: 0)]
            } else {
                bodies = parsed.notes.enumerated().map { index, note in
                    // 说明里点名了哪张图就用哪张（「雨窗」「猫」），
                    // 没点名才按文字哈希随便落一张。
                    let seed = MockPhotoSubject.matching(note)?.seed
                        ?? PhotoTextParser.seed(for: note)
                    return (text: index == 0 ? parsed.body : note, seed: seed)
                }
            }

            for body in bodies {
                guard !body.text.isEmpty || body.seed > 0 else { continue }

                let message = StoredMessage(
                    characterUID: character.uid,
                    role: .assistant,
                    text: body.text,
                    speaker: line.speaker,
                    isNarration: line.isNarration,
                    imageSeed: body.seed,
                    createdAt: Date().addingTimeInterval(Double(offset) * 0.001)
                )
                message.character = character
                context.insert(message)
                lastText = body.text.isEmpty ? "发了一张图" : body.text
                offset += 1
            }
        }

        character.totalReplies += 1
        character.lastMessageAt = Date()
        // 这一轮谁真的开口了。群聊的状态增量要归他们，不能一律记在群主头上。
        // `spoken` 保留顺序和重复次数：挑「说话最多的人」时要用。
        let spoken = lines.compactMap(\.speaker).filter { !$0.isEmpty }
        let speakers = Array(Set(spoken)).sorted()
        applySideEffects(
            meta,
            names: names,
            speakers: speakers,
            spoken: spoken,
            character: character,
            context: context
        )
        recordDay(meta, for: character, speakers: speakers, context: context)
        applyRefresh(
            meta,
            refresh: refresh,
            enabledPages: settings.refreshRules.filter(\.enabled).map(\.page),
            for: character
        )
        save(context)

        if settings.notifyReplies {
            ReplyNotifier.notifyReply(characterName: character.name, text: lastText)
        }

        // 按次计费时状态增量已经在同一次回复里带回，不再单独发起压缩调用。
        guard !plan.mergesSideEffects else { return }

        Task { @MainActor [weak self] in
            await self?.compressMemoryIfNeeded(
                character: character,
                context: context,
                settings: settings
            )
        }
    }


    /// 落库。`internal` 而不是 `private`：记忆压缩拆在另一个文件里，
    /// 那边也要用同一个入口，各写一份 try/catch 迟早有一处漏了。
    func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            AppLog.storage.error("保存失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 记忆压缩

    // 实现在 `ChatViewModel+Memory.swift`：群聊要按人分层写，
    // 那段规则比发送和落库复杂得多，留在主文件里挤掉了别的。

    func clearError() {
        errorText = nil
    }
}
