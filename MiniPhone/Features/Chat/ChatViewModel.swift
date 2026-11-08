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
        quoteText: String = ""
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
        userMessage.character = character
        context.insert(userMessage)
        character.lastMessageAt = Date()
        save(context)
        // 火花记的是「今天我说过话」。他那边开口在 `recordDay` 里记。
        WorldStore.shared.markCoupleDay(fromMe: true)

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

        let history = Array(
            character.messages
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

        // 这会儿真的在放的那首。暂停了就当没在听——「在听」是状态不是历史。
        let player = PlayerService.shared
        let listeningNow = player.isPlaying ? player.track : nil

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
            stickerNames: StickerLibrary.shared.names(for: character)
        )

        var request: [ChatMessage] = [ChatMessage(role: .system, text: system)]
        request.append(contentsOf: history.map { $0.asChatMessage })

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
        applySideEffects(meta, names: names, character: character, context: context)
        recordDay(meta, for: character)
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

    /// 把这一轮记进角色当天的那一页。
    ///
    /// 日程本身是本地排出来的，聊过之后才盖上「这天说过话」的章，
    /// 并把模型给的 dayLog 挂上去。角色之后说「昨天我们聊到……」靠的就是它。
    private func recordDay(_ meta: ReplyEnvelope.Meta?, for character: Companion) {
        let world = WorldStore.shared

        world.ensureCharacterDay(
            named: character.name,
            wakeHour: character.wakeHour,
            sleepHour: character.sleepHour,
            replies: character.totalReplies
        )

        let log = meta?.dayLog?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        world.noteCharacterChat(named: character.name, summary: log)
        world.markCoupleDay(fromMe: false)
    }

    /// 状态块里带回来的增量统一写进 WorldStore。
    /// 群聊里发生的事按所有相关人物归档，所以回到单聊时读得到同一份记忆。
    private func applySideEffects(
        _ meta: ReplyEnvelope.Meta?,
        names: [String],
        character: Companion,
        context: ModelContext
    ) {
        guard let meta else { return }
        let world = WorldStore.shared

        if let raw = meta.mood, let mood = Mood(rawValue: raw) {
            world.updateMood(mood, reason: meta.moodReason ?? "", source: .chat)
        }
        if let voice = meta.voice {
            world.appendVoice(person: character.name, text: voice, source: .chat)
        }
        if let memory = meta.memory {
            for name in names {
                world.recordFact(person: name, text: memory, sourceName: character.name)
            }
        }
        if let note = meta.scheduleNote, !note.isEmpty {
            world.recordFact(person: character.name, text: "日程：\(note)", sourceName: character.name)
        }
        if let moment = meta.moment, !moment.isEmpty {
            context.insert(
                MomentPost(
                    characterUID: character.uid,
                    characterName: character.name,
                    text: moment
                )
            )
        }
        if let raw = meta.voiceResolvedID, let id = UUID(uuidString: raw) {
            world.resolveVoice(id: id)
        }
    }

    /// 把这一轮带回来的页面增量写进世界状态。
    ///
    /// 判定过要刷、模型却什么都没给，是正常会发生的（它觉得最近没线索）。
    /// 这种情况不清零计数，下一轮还能再判一次，不会白等六轮。
    private func applyRefresh(
        _ meta: ReplyEnvelope.Meta?,
        refresh: RefreshRequest?,
        enabledPages: [RefreshPage],
        for character: Companion
    ) {
        let world = WorldStore.shared

        guard let refresh, let meta else {
            world.noteTurn(pages: enabledPages)
            return
        }

        var added = 0
        if refresh.wantsShop {
            added += world.applyShopDrafts(meta.shop ?? [], limit: refresh.shopLimit)
        }
        if refresh.wantsFeed {
            added += world.applyFeedDrafts(
                meta.feed ?? [],
                author: character.name,
                authorUID: character.uid.uuidString,
                limit: refresh.feedLimit
            )
            added += world.applyFeedComments(meta.feedComments ?? [], limit: refresh.commentLimit)
        }

        if added > 0 {
            world.markRefreshed(refresh.pages)
            // App 不在前台时补一条本地通知；在前台由外壳弹玻璃横幅，不走系统通知。
            ReplyNotifier.notifyRefresh(text: refresh.notices.joined(separator: "\n"))
        } else {
            world.noteTurn(pages: enabledPages)
        }
    }

    private func relatedNames(for character: Companion) -> [String] {
        var names = [character.name]
        if character.isGroup {
            names.append(contentsOf: character.membersNote
                .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == "\n" })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        }
        return Array(Set(names))
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            AppLog.storage.error("保存失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 记忆压缩

    /// 老消息压成一段摘要，原消息保留在库里但不再送进上下文。
    ///
    /// 摘要同时归档到人物级记忆：群聊和单聊读同一份，不会各存各的。
    private func compressMemoryIfNeeded(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        let plan = settings.generationPlan
        let cursor = character.memoryCursor ?? .distantPast
        let pending = character.messages
            .filter { $0.createdAt > cursor }
            .sorted { $0.createdAt < $1.createdAt }

        guard pending.count > plan.compressionThreshold else { return }

        let batch = Array(pending.prefix(pending.count - plan.keepRecent))
        guard !batch.isEmpty else { return }

        let transcript = batch
            .map { message -> String in
                let who = message.role == .user ? "用户" : (message.speaker ?? character.name)
                return "\(who)：\(message.text)"
            }
            .joined(separator: "\n")

        let previous = character.memorySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        \(PromptBuilder.memoryCompressionPrompt)

        \(previous.isEmpty ? "" : "【已有的旧记忆】\n\(previous)\n")

        【需要并入的新对话】
        \(transcript)
        """

        let client = OpenAICompatibleClient(config: settings.config)

        do {
            let summary = try await client.complete([
                ChatMessage(role: .system, text: "你是一个精确的对话记录整理者，只输出整理后的备忘正文。"),
                ChatMessage(role: .user, text: prompt)
            ])

            let clean = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            character.memorySummary = clean
            if let lastDate = batch.last?.createdAt {
                character.memoryCursor = lastDate
            }
            save(context)

            let world = WorldStore.shared
            world.appendMemorySummary(person: character.name, text: clean)
            for name in relatedNames(for: character) {
                world.recordFact(person: name, text: clean, sourceName: character.name)
            }
        } catch {
            // 压缩失败不影响聊天，下次再压。
            AppLog.storage.error("记忆压缩失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearError() {
        errorText = nil
    }
}
