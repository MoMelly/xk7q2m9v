import Foundation
import SwiftData

/// 记忆压缩：把已经滑出上下文窗口的老消息压成摘要。
///
/// 原消息留在库里，只是不再送进上下文——删掉就没法回看，也补不回来。
///
/// 一对一和群聊落库的位置不一样，这是这一层唯一复杂的地方：
/// - 一对一：摘要写进 `character.memorySummary` 和 `people[他的名字].summary`，
///   两处是同一份文本（前者给西瓜皮私信读，后者给聊天提示词读）。
/// - 群聊：让模型按人分层输出。群里那段写进 `people[群名].summary`，
///   每个人那段写进他自己的 `groupNotes[群名]`，**不动**他一对一的那份摘要。
///   群聊不写 `character.memorySummary`：群不是一个人，那个字段是「他自己的记忆」。
extension ChatViewModel {

    func compressMemoryIfNeeded(
        character: Companion,
        context: ModelContext,
        settings: SettingsStore
    ) async {
        let plan = settings.generationPlan
        let cursor = character.memoryCursor ?? .distantPast
        // 只压当前身份这一段：记忆是按人分开的，另一个身份聊过的东西
        // 不该被压进这个人的摘要里。
        let pending = character.scopedMessages
            .filter { $0.channel == .chat && $0.createdAt > cursor }
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

        let client = OpenAICompatibleClient(config: settings.config)
        let world = WorldStore.shared
        let lastDate = batch.last?.createdAt

        let compressed: Bool
        if character.isGroup {
            compressed = await compressGroup(
                character: character,
                members: relatedNames(for: character).filter { $0 != character.name },
                transcript: transcript,
                client: client,
                world: world
            )
        } else {
            compressed = await compressSolo(
                character: character,
                transcript: transcript,
                client: client,
                world: world
            )
        }

        // 游标只在压缩真的写成之后推进。失败时推了游标，这批老消息就
        // 再也不会被 `createdAt > cursor` 选中，一次网络错误等于永久丢掉这段记忆。
        guard compressed, let lastDate else { return }
        character.memoryCursor = lastDate
        save(context)
    }

    // MARK: - 一对一

    private func compressSolo(
        character: Companion,
        transcript: String,
        client: OpenAICompatibleClient,
        world: WorldStore
    ) async -> Bool {
        let previous = character.activeMemorySummary
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let prompt = """
        \(PromptBuilder.memoryCompressionPrompt)

        \(previous.isEmpty ? "" : "【已有的旧记忆】\n\(previous)\n")

        【需要并入的新对话】
        \(transcript)
        """

        do {
            let summary = try await client.complete([
                ChatMessage(role: .system, text: "你是一个精确的对话记录整理者，只输出整理后的备忘正文。"),
                ChatMessage(role: .user, text: prompt)
            ])
            let clean = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return false }

            // 这是「整段重写」的结果，不是增量。用 append 的话每压一次就多一份，
            // 1200 字的上限被几份旧摘要挤满，最新那份反而被切掉半截。
            character.setActiveMemorySummary(clean)
            world.replaceMemorySummary(person: character.name, text: clean)
            return true
        } catch {
            // 压缩失败不影响聊天，下次再压。
            AppLog.storage.error("记忆压缩失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - 群聊

    /// 群聊记忆按人拆开写。
    ///
    /// 原来压出一整段、挂到群主名下，然后**把整段当成一条 fact 塞给群里每个人**。
    /// 那个 fact 会占掉 14 条事实配额里的一条，内容却是一千多字的摘要，
    /// 提示词里整块「共同记得的事」都被它挤走了。
    ///
    /// 现在：群那段进群记忆，人那段进各人的 `groupNotes`。谁在群里说了什么，
    /// 只有他自己那份记得最细；群里共同的事，谁都能想起来。
    private func compressGroup(
        character: Companion,
        members: [String],
        transcript: String,
        client: OpenAICompatibleClient,
        world: WorldStore
    ) async -> Bool {
        let previous = world.memorySummary(for: character.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 成员表先同步一次：单聊要靠它反查「他在哪些群里」。
        world.syncGroup(named: character.name, members: [character.name] + members)

        let prompt = GroupDigest.prompt(
            group: character.name,
            members: members,
            previous: previous,
            transcript: transcript
        )

        do {
            let raw = try await client.complete([
                ChatMessage(role: .system, text: "你是一个精确的群聊记录整理者。只按要求的格式输出分节的备忘，不要解释。"),
                ChatMessage(role: .user, text: prompt)
            ])
            let digest = GroupDigest.parse(raw, members: members)
            guard !digest.group.isEmpty else { return false }

            world.replaceMemorySummary(person: character.name, text: digest.group)
            for person in digest.people {
                world.setGroupNote(
                    person: person.name,
                    group: character.name,
                    text: person.text
                )
            }
            return true
        } catch {
            AppLog.storage.error("群聊记忆压缩失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
