import Foundation

extension PromptBuilder {
    /// 角色主动触达时用的系统指令。输出是结构化的一行 JSON，
    /// 界面按 kind 分到两条独立通道里，不靠自然语言猜它想发什么。
    static let proactiveFeedSystem = """
    你正在扮演一个角色，要自己决定在「西瓜皮」上给用户发点什么。
    只输出一行 JSON，不要解释、不要 markdown、不要代码块。
    格式：{"kind":"dm","text":"...","note":0}
    kind 只能是 dm（一条私信）或 share（转一篇帖子）。
    note 是候选帖子的编号，从 1 开始；kind 为 dm 时填 0。
    text 一两句，用你自己的说话方式，不要写成通知或系统消息。
    不要问用户可不可以，也不要写「如果你愿意」——这件事你自己决定。
    """

    static func proactiveFeedPrompt(
        character: Companion,
        notes: [FeedNote],
        activityLines: [String]
    ) -> String {
        var lines: [String] = [
            "你是\(character.name)。",
            "【你的人设】\(character.persona.isEmpty ? "（没写具体设定，按名字保持一致）" : character.persona)",
            ""
        ]
        if !activityLines.isEmpty {
            lines.append("【你最近在西瓜皮做过的事，不要重复做同一件】")
            lines.append(contentsOf: activityLines)
            lines.append("")
        }
        if notes.isEmpty {
            lines.append("现在西瓜皮上还没有帖子可转，这次只能发私信（kind=dm）。")
        } else {
            lines.append("【可以转的帖子】")
            for (index, note) in notes.enumerated() {
                lines.append("\(index + 1). 《\(note.title)》· \(note.tag) · \(note.authorName)")
            }
            lines.append("想聊点什么就转一篇相关的，没有想聊的就发私信。")
        }
        lines.append("")
        lines.append("现在给出这一次的 JSON。")
        return lines.joined(separator: "\n")
    }

    /// 私信 / 转帖对话的系统提示。
    ///
    /// 两条通道共用这一份角色记忆：历史消息按 thread 取，滚动摘要和
    /// 「最近在西瓜皮做过的事」照常带上，所以在「信息」里聊也能接得上。
    /// 转帖额外注入帖子标题正文，对话才不会跑题。
    static func feedChatSystem(
        character: Companion,
        item: FeedInboxItem,
        activityLines: [String],
        userName: String?
    ) -> String {
        var blocks: [String] = []
        blocks.append("你正在扮演一个角色和用户对话。你就是这个角色本人，不要跳出角色，不要提到自己是模型或程序。")
        blocks.append("【角色】\(character.name)\n" + (character.persona.isEmpty ? "（没有写具体设定，按名字和对话内容保持一致。）" : character.persona))

        if let userName, !userName.isEmpty {
            blocks.append("【对方是谁】他叫\(userName)。按你和他现在的关系说话。")
        }

        if !character.memorySummary.isEmpty {
            blocks.append("【很久以前发生过什么】\n" + character.memorySummary)
        }

        if item.kind == .postShare {
            blocks.append("""
            【你转给我的那篇帖子】
            标题：《\(item.noteTitle)》
            话题：\(item.noteTag)
            正文：\(item.noteBody)
            你附了一句：\(item.message)
            现在围着这篇帖子聊，不要突然换到完全无关的事上。
            """)
        } else {
            blocks.append("【你在西瓜皮给我发的私信】\(item.message)")
        }

        if !activityLines.isEmpty {
            blocks.append("【你最近在西瓜皮做过的事】\n" + activityLines.joined(separator: "\n"))
        }

        blocks.append("这是西瓜皮的私信，不是主聊天界面。回复要短，像手机消息，一两句为主，不要写旁白和括号动作。")
        return blocks.joined(separator: "\n\n")
    }
}
