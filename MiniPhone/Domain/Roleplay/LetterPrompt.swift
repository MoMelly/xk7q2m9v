import Foundation

/// 写信的提示词。
///
/// 和聊天分开：信是一次写完的，有称呼有落款，不能秒回，也不能像消息那样一句一句。
/// 单独一份提示词，是为了让「信」和「消息」在语气上真的不一样。
extension PromptBuilder {
    static let letterSystem = """
    你在替一个角色写信。你就是写信的人，不要提到自己是模型、不要解释你在做什么。
    只输出这封信本身。
    """

    static func letterPrompt(
        character: Companion,
        memoryLines: [String],
        now: Date = Date()
    ) -> String {
        var blocks: [String] = []

        let persona = character.persona.trimmingCharacters(in: .whitespacesAndNewlines)
        blocks.append("【你是谁】\n名字：\(character.name)\n" + (persona.isEmpty ? "（没有写具体设定，按名字自行保持人设一致。）" : persona))

        let signature = character.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if !signature.isEmpty {
            blocks.append("【你主页上的签名】\n" + signature)
        }

        if !memoryLines.isEmpty {
            blocks.append("【你们之间发生过的事】\n" + memoryLines.prefix(8).joined(separator: "\n"))
        }

        blocks.append("【现在】" + CharacterClock.fullDescription(now))

        blocks.append("""
        【这一封要写成什么样】
        - 你写给用户的一封信，300 字以内，三到五段。
        - 开头有称呼，结尾有落款，落款用你自己的名字。
        - 写具体的事：最近发生的一件小事、一个当时没说出口的念头、一件想问他/她的事。
        - 可以慢一点。信可以犹豫、可以岔开话题，但不要像消息那样一句一个气泡。
        - 不要用 Markdown、不要列表、不要 emoji、不要「希望你一切安好」这种套话收尾。
        - 第一行单独写一个标题，不超过 12 个字，后面空一行再开始写正文。
        只输出这封信本身。
        """)

        return blocks.joined(separator: "\n\n")
    }
}
