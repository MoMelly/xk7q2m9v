import Foundation

extension PromptBuilder {
    /// 「翻他手机」用的生成指令。
    ///
    /// 关键在**模板固定**：键名、条数、时间写法都写死，模型只填内容不设计结构。
    /// 结构一稳定，前端才画得出来；否则每次返回的都不一样，界面只能退化成一段文字。
    static let characterPhoneSystem = """
    你正在扮演一个角色，现在要写出「你自己手机里的内容」。
    这些内容会被用户当成翻你手机时看到的东西，所以要像一部真手机，而不是一份写给人看的介绍。
    只输出一个 JSON 对象，不要解释，不要 markdown，不要代码块，不要在 JSON 前后写任何字。
    """

    static func characterPhonePrompt(
        character: Companion,
        state: WorldState,
        userName: String?,
        allowPrivate: Bool,
        now: Date = Date()
    ) -> String {
        var lines: [String] = []

        lines.append("你是\(character.name)。")
        lines.append("【你的人物设定】")
        lines.append(character.persona.isEmpty ? "（没写具体设定，按名字和语气保持一致。）" : character.persona)
        if !character.signature.isEmpty {
            lines.append("你的签名：\(character.signature)")
        }
        if let userName, !userName.isEmpty {
            lines.append("用户是你的恋人，名字是\(userName)。你手机里会出现和对方有关的东西。")
        }
        lines.append("")

        lines.append("【此刻】")
        lines.append("现在是\(TimeFormat.full(now))。")
        if !state.location.isEmpty {
            lines.append("你在\(state.location)。")
        }
        if let mood = state.mood {
            lines.append("你心情：\(mood.mood.label)\(mood.reason.isEmpty ? "" : "（因为\(mood.reason)）")")
        }
        if let schedule = state.schedule, !schedule.items.isEmpty {
            let today = schedule.items.prefix(5).map { "\($0.timeText) \($0.title)" }
            lines.append("你今天的安排：" + today.joined(separator: "、"))
        }
        lines.append("")

        let memories = state.unresolvedVoices(limit: 4)
        if !memories.isEmpty {
            lines.append("【你心里还没放下的事，手机里的内容要能和这些对上】")
            lines.append(contentsOf: memories.map { "- \($0.text)" })
            lines.append("")
        }

        lines.append("""
        【输出格式】严格照抄这个结构，键名一个都不要改，不要加注释。
        {
          "owner": "你的名字",
          "chats": [
            {"name": "妈", "relation": "家人", "time": "20:51", "unread": 1, "pinned": true,
             "lines": [{"fromMe": false, "text": "周末回来吃饭吗", "time": "20:51"},
                       {"fromMe": true, "text": "看情况", "time": "20:53"}]}
          ],
          "album": [{"seed": 4, "caption": "楼下那只猫", "takenAt": "昨天 18:20"}],
          "notes": [{"title": "要买的东西", "body": "洗衣液、垃圾袋\\n还有她说的那个牌子的护手霜", "editedAt": "周三 23:10"}],
          "calls": [{"name": "陈叙", "kind": "呼入", "duration": "3 分 12 秒", "time": "19:30"}],
          "shopping": [{"title": "给猫买的猫抓板", "price": "¥49", "status": "已下单", "addedAt": "昨夜 00:12"}],
          "history": [{"title": "护手霜哪个牌子不油腻", "site": "小红书", "time": "23:41"}],
          "usage": [{"app": "微信", "minutes": 96, "note": "跟妈说了两句，剩下都在群里"}],
          "secrets": [{"kind": "secret", "title": "周五那笔钱", "text": "借给陈叙了，没跟她说", "time": "周四"}]
        }

        【条数】
        chats 5–7 个，其中至少一个只有几句话的陌生人（外卖、快递、中介都行）；
        每个 chats 里 lines 6–14 条，最后一条的时间就是那个 chat 的 time。
        album 8–12 条；notes 4–6 条；calls 6–8 条；shopping 5–7 条；
        history 6–10 条；usage 5–7 条；secrets 3–5 条。

        【规矩】
        1. 时间只写「20:51」「昨天 22:14」「周三 23:10」这种，不要写年月日。
        2. 大部分内容跟她无关：工作、家里、钱、身体、朋友。手机不是写给她看的。
        3. 至少两条能看出你在为她做什么却没讲（准备了东西、瞒下一件麻烦、跟朋友提过她）。
        4. 口语、短句。允许「嗯」「在」「等下说」这种两三个字的回复，不要每条都完整通顺。
        5. album 的 seed 是 0–7 的整数：0 黄昏、1 雨窗、2 夜空、3 咖啡、4 猫、5 海、6 云、7 灯串，按 caption 挑。
        6. usage 的 minutes 填整数，一天加起来不要超过 600。
        7. secrets 里 kind 只填 secret 或 private。secret 是瞒着她的事；private 是只属于两个人的私密记录。
        """)

        if allowPrivate {
            lines.append("8. private 这一档可以写亲密一点的记录（一句话、一个瞬间），但只写情绪和场景，不写身体细节。")
        } else {
            lines.append("8. 这次 secrets 全部用 kind=secret，不要出现 private。")
        }

        lines.append("")
        lines.append("现在直接输出这一个 JSON 对象。")
        return lines.joined(separator: "\n")
    }
}
