import Foundation

/// 把角色配置、玩法、设定集、时间拼成一段系统提示词。
///
/// 这一层是「酒馆兼容」的落点：V2 角色卡里的 description / first_mes
/// 直接进 `人设` 和 `开场白`；世界书条目进 `设定集` 的关键词匹配。
/// 剩下的采样参数、正则、宏不暴露给用户，全部由这里固定。
enum PromptBuilder {
    static func systemPrompt(
        character: Companion,
        worldEntries: [WorldEntry],
        triggerText: String,
        now: Date = Date(),
        lastMessageAt: Date?
    ) -> String {
        var blocks: [String] = []

        // 身份
        blocks.append("你正在扮演一个角色和用户对话。你就是这个角色本人，不要跳出角色，不要提到自己是模型或程序。")

        // 人设
        let persona = character.persona.trimmingCharacters(in: .whitespacesAndNewlines)
        blocks.append("【角色】\(character.name)\n" + (persona.isEmpty ? "（没有写具体设定，按名字和对话内容自行保持人设一致。）" : persona))

        // 玩法
        blocks.append("【对话形式】\n" + character.preset.promptRules)

        // 群聊
        if character.isGroup {
            let members = character.membersNote.trimmingCharacters(in: .whitespacesAndNewlines)
            blocks.append("""
            【这是群聊】成员包括\(members.isEmpty ? "你和其他几位" : members)。
            - 每条回复里，每句话单独一行，以「名字：」开头，名字必须是上述成员之一。
            - 一次可以有一到三个人说话，像真的群聊那样有人接话、有人不接。
            - 不要写旁白，不要写谁在做什么动作，只写台词。
            """)
        }

        // 长度
        blocks.append("【长度】" + character.replyLength.instruction)

        // 时间与作息
        blocks.append("【时间】" + CharacterClock.promptContext(character, now: now, lastMessageAt: lastMessageAt))

        // 记忆
        let memory = character.memorySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !memory.isEmpty {
            blocks.append("【你记得的往事】\n" + memory)
        }

        // 设定集命中
        let hits = matchedEntries(worldEntries, triggerText: triggerText, character: character)
        if !hits.isEmpty {
            blocks.append("【设定】\n" + hits.joined(separator: "\n"))
        }

        // 输出硬性约束
        blocks.append("""
        【输出要求】
        - 只输出角色说的话（剧情模式可带括号内的动作），不要加任何解释、标题、列表符号。
        - 不要用 Markdown，不要用 **加粗**、`代码`、# 标题。
        - 不要替用户说话，不要描写用户做了什么。
        - 不要在结尾追问「还有什么可以帮你的」这类助手式收尾。
        """)

        return blocks.joined(separator: "\n\n")
    }

    /// 关键词命中的设定条目。全局条目 + 本角色条目都参与。
    static func matchedEntries(
        _ entries: [WorldEntry],
        triggerText: String,
        character: Companion
    ) -> [String] {
        guard !triggerText.isEmpty else { return [] }
        let haystack = triggerText.lowercased()

        return entries.compactMap { entry in
            guard entry.enabled else { return nil }
            if let owner = entry.characterUID, owner != character.uid { return nil }
            let keywords = entry.keywordList
            guard !keywords.isEmpty else { return nil }
            let hit = keywords.contains { haystack.contains($0.lowercased()) }
            guard hit else { return nil }
            let content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }
    }

    /// 动态墙那条状态的提示词。
    ///
    /// 放在这里而不是写在界面里：提示词一旦分散到各页面，
    /// 想统一调语气就只能靠全局搜索，而且很容易漏掉一处。
    static func momentPrompt(character: Companion, now: Date = Date()) -> String {
        let persona = character.persona.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        你在替一个角色写一条发在社交动态上的短内容。
        \(persona.isEmpty ? "角色名：\(character.name)。" : persona)
        现在的时间是\(CharacterClock.fullDescription(now))。
        要求：
        - 两三句话，像随手发的那样，不要标题、不要 hashtag、不要堆 emoji。
        - 用第一人称，符合角色身份和当前时间段。
        - 不要提到自己在被谁要求写。
        只输出正文。
        """
    }

    /// 记忆压缩用的提示词。
    static let memoryCompressionPrompt = """
    你在整理一段对话的长期记忆。
    把下面这些消息压缩成一段第三人称的备忘，用于以后回想。
    要求：
    - 只保留事实：发生过什么、说过的关键信息、情绪转折、约定。
    - 去掉寒暄和重复。
    - 用「用户」「TA」指代双方，不要编造没出现过的内容。
    - 三百字以内，一段话，不要分点。
    """
}
