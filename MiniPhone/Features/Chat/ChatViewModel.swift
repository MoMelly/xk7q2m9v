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

    /// 送进模型的上下文窗口。40 条大约覆盖两三千字，再长就该靠摘要了。
    private let contextWindow = 40
    /// 未压缩消息超过这个数就触发一次摘要。
    private let compressionThreshold = 40
    /// 压缩时永远保留最近这么多条原文，保证短期细节不丢。
    private let keepRecent = 20

    var displayedStreamingText: String { streamingText }

    // MARK: - 发送

    func send(
        _ raw: String,
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        guard settings.isConfigured else {
            errorText = "还没填 API Key。点右上角齿轮填一个。"
            return
        }

        errorText = nil

        let userMessage = StoredMessage(characterUID: character.uid, role: .user, text: text)
        userMessage.character = character
        context.insert(userMessage)
        character.lastMessageAt = Date()
        save(context)

        await generateReply(for: character, context: context, settings: settings)
    }

    /// 重新生成最后一条回复：先删掉最后一条助手消息，再走一遍生成。
    func regenerate(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        guard !isStreaming else { return }
        let sorted = character.messages.sorted { $0.createdAt < $1.createdAt }
        guard let last = sorted.last, last.role == .assistant else { return }

        context.delete(last)
        save(context)
        await generateReply(for: character, context: context, settings: settings)
    }

    private func generateReply(
        for character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        isStreaming = true
        streamingText = ""
        defer {
            isStreaming = false
            streamingText = ""
        }

        let history = Array(
            character.messages
                .sorted { $0.createdAt < $1.createdAt }
                .suffix(contextWindow)
        )

        let trigger = history
            .filter { $0.role == .user }
            .suffix(3)
            .map { $0.text }
            .joined(separator: "\n")

        let allEntries = (try? context.fetch(FetchDescriptor<WorldEntry>())) ?? []
        let system = PromptBuilder.systemPrompt(
            character: character,
            worldEntries: allEntries,
            triggerText: trigger,
            lastMessageAt: history.dropLast().last?.createdAt
        )

        var request: [ChatMessage] = [ChatMessage(role: .system, text: system)]
        request.append(contentsOf: history.map { $0.asChatMessage })

        let client = OpenAICompatibleClient(config: settings.config)

        do {
            for try await piece in client.streamChat(request) {
                streamingText += piece
            }

            let reply = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                errorText = "模型一个字都没返回。可能是余额不足，或者这个模型不支持流式。"
                return
            }

            persist(reply, for: character, context: context, settings: settings)
        } catch {
            errorText = error.localizedDescription
            AppLog.ui.error("生成失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 落库

    private func persist(
        _ reply: String,
        for character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) {
        let lines = character.isGroup
            ? ReplyParser.parseGroup(reply)
            : ReplyParser.parseSingle(reply)

        var lastText = reply
        for (index, line) in lines.enumerated() {
            let message = StoredMessage(
                characterUID: character.uid,
                role: .assistant,
                text: line.text,
                speaker: line.speaker,
                isNarration: line.isNarration,
                createdAt: Date().addingTimeInterval(Double(index) * 0.001)
            )
            message.character = character
            context.insert(message)
            lastText = line.text
        }

        character.totalReplies += 1
        character.lastMessageAt = Date()
        save(context)

        if settings.notifyReplies {
            ReplyNotifier.notifyReply(characterName: character.name, text: lastText)
        }

        Task { @MainActor [weak self] in
            await self?.compressMemoryIfNeeded(
                character: character,
                context: context,
                settings: settings
            )
        }
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
    /// 不做向量检索那套：单人自用、单个角色，滚动的文字摘要已经够用，
    /// 而且它可读——出问题时能直接看到「它以为记住了什么」。
    private func compressMemoryIfNeeded(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        let cursor = character.memoryCursor ?? .distantPast
        let pending = character.messages
            .filter { $0.createdAt > cursor }
            .sorted { $0.createdAt < $1.createdAt }

        guard pending.count > compressionThreshold else { return }

        let batch = Array(pending.prefix(pending.count - keepRecent))
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

            character.memorySummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if let lastDate = batch.last?.createdAt {
                character.memoryCursor = lastDate
            }
            save(context)
        } catch {
            // 压缩失败不影响聊天，下次再压。
            AppLog.storage.error("记忆压缩失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearError() {
        errorText = nil
    }
}
