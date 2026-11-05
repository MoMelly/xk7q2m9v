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
        lastMessageAt: Date?,
        worldContext: WorldContext? = nil,
        metaBlockRequired: Bool = false,
        refresh: RefreshRequest? = nil,
        callMode: Bool = false,
        userIdentity: UserIdentity? = nil
    ) -> String {
        var blocks: [String] = []

        // 身份
        blocks.append("你正在扮演一个角色和用户对话。你就是这个角色本人，不要跳出角色，不要提到自己是模型或程序。")

        // 人设
        let persona = character.persona.trimmingCharacters(in: .whitespacesAndNewlines)
        blocks.append("【角色】\(character.name)\n" + (persona.isEmpty ? "（没有写具体设定，按名字和对话内容自行保持人设一致。）" : persona))

        // 主页上自己写的那句签名和几个标签，代表他希望别人看到的形象。
        var profile: [String] = []
        let signature = character.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if !signature.isEmpty { profile.append("签名：\(signature)") }
        if !character.tags.isEmpty { profile.append("标签：" + character.tags.joined(separator: "、")) }
        if !profile.isEmpty {
            blocks.append("【你在主页上怎么写自己】\n" + profile.joined(separator: "\n"))
        }

        // 对方是谁。同一个人可以换身份来聊，角色得跟着换称呼和态度。
        if let userIdentity {
            var lines: [String] = ["他叫\(userIdentity.name)。"]
            let userSignature = userIdentity.signature.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userSignature.isEmpty { lines.append("签名：\(userSignature)") }
            let bio = userIdentity.bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !bio.isEmpty { lines.append("他自己写的介绍：\(bio)") }
            if !userIdentity.tags.isEmpty {
                lines.append("标签：" + userIdentity.tags.joined(separator: "、"))
            }
            if userIdentity.isBlank {
                lines.append("你没见过他别的资料。不知道的事就问，不要替他补设定。")
            }
            lines.append("按这个身份跟他说话：称呼、语气、分寸都按你和他现在的关系来。")
            blocks.append("【对方是谁】\n" + lines.joined(separator: "\n"))
        }

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

        // 通话：同一个人，换了个介质。说话方式要跟着变，不然跟打字没区别。
        if callMode {
            blocks.append("""
            【现在在通电话】
            - 你们在打电话，不是在发消息。只写你嘴上说出来的话，一句话一行，一句 25 字以内。
            - 不写旁白、不写动作、不加括号说明、不加时间戳。电话里没有这些。
            - 像真的通话：可以「喂？」开头，可以说到一半停住，可以被打断，可以沉默一下再开口。
            - 不要每句都完整，口语本来就碎。
            """)
        }

        // 记忆
        let memory = character.memorySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !memory.isEmpty {
            blocks.append("【你记得的往事】\n" + memory)
        }

        // 跨会话世界状态：人物记忆、心声、日程、心情、设备快照。
        if let worldContext {
            let block = worldBlock(worldContext)
            if !block.isEmpty {
                blocks.append(block)
            }
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

        // 按次计费时，把状态增量挤进同一次回复，省掉后台那些独立调用。
        // 要刷新页面的那一轮也必须有这个块，否则刷出来的内容没地方放。
        if metaBlockRequired || refresh != nil {
            blocks.append("""
            【附加状态块】
            正文之后另起一行，输出一段机器可读的 JSON，以 <<<meta>>> 开头、<<<end>>> 结尾。
            字段全部可选：mood（calm/glad/focused/tired/annoyed/low/excited）、moodReason、
            voice（这一轮没说出口的一句心里话）、memory（这一轮新记住的一个事实）、
            dayLog（这一轮聊完之后，用一句「今天」视角的话概括你们说了什么，25 字内）、
            scheduleNote、moment（一条可以发出去的动态）、voiceResolvedID（某个心结被解开了就填它的 id）。
            只有确实发生了变化才填对应字段，没有就输出 {}。
            正文里不要提到这个块，也不要把它写进台词。
            """)
        }

        if let refresh {
            blocks.append(refreshBlock(refresh))
        }

        return blocks.joined(separator: "\n\n")
    }

    /// 刷新的指令。
    ///
    /// 单独成块而不是塞进状态块说明里：这一块只在被判定的轮次出现，
    /// 混在一起会让模型以为每轮都要产商品。
    private static func refreshBlock(_ request: RefreshRequest) -> String {
        var lines: [String] = [
            "【这一轮顺便刷新】",
            "用户会在这部手机里打开下面这些页面。这一轮把它们的内容换一批，写进状态块的对应字段，",
            "不要写进台词，也不要在对话里提「我给你刷新了」之类的话——他看到的就是页面自己变了。"
        ]

        if request.wantsShop {
            lines.append("""
            - shop：\(request.shopLimit - 1)~\(request.shopLimit) 件商品。
              title 商品名（12 字内）；price 数字，单位元，按普通学生能接受的水平，几十到一百多；
              note 你自己的一句反应或推荐（20 字内，可以有情绪）；
              reason 你依据的那件事，尽量引用他刚说过的原话（30 字内）；
              category 一个词：数码 / 吃的 / 日用 / 书 / 穿的。
              依据必须是最近对话里真实出现过的东西或需求。他随口提一句「耳机又坏了」才推耳机，
              什么线索都没有就别写这个字段。
            """)
        }

        if request.wantsFeed {
            lines.append("""
            - feed：\(request.feedLimit) 条笔记。
              title 20 字内，body 60 字内，tag 一个话题词，
              author 是发这条的账号名（可以是你自己，也可以是别人的号），
              comments 给 0~2 句底下的人说的话。
              内容是用户最近聊到的事延伸出去的，不要凭空编一个跟他无关的话题。
            """)
        }

        if !request.commentTargets.isEmpty {
            let titles = request.commentTargets.map { "「\($0)」" }.joined(separator: "、")
            lines.append("""
            - feedComments：给你自己以前发过的笔记补 \(request.commentLimit) 条评论。
              title 字段原样照抄下面其中一个标题：\(titles)
              author 写评论的人（可以是别的角色，也可以是路人），text 一句话，30 字内。
              这是「过了一段时间又有人来留言」，语气要像隔了一阵子才看到，不要复读原帖。
              没什么可说的就不写。
            """)
        }

        lines.append("两个字段都可以不写。宁可这一次什么都不刷，也不要硬凑。")
        return lines.joined(separator: "\n")
    }

    /// 世界状态进提示词的唯一装配点。
    ///
    /// 心声带 id 是为了让模型能明确指认「哪件心结了结了」；
    /// 带 lastReferencedAt 的心声仍会保留，但要求别每轮重复念一遍。
    private static func worldBlock(_ context: WorldContext) -> String {
        var parts: [String] = []

        var memoryLines = context.summaries
        memoryLines.append(contentsOf: context.facts.map { "- \($0.text)" })
        if !memoryLines.isEmpty {
            parts.append("【共同记得的事】\n" + memoryLines.joined(separator: "\n"))
        }

        if !context.voices.isEmpty {
            let lines = context.voices.map { voice in
                "- [\(voice.id.uuidString)] \(voice.personName)：\(voice.text)"
            }
            parts.append("""
            【还没放下的心事】
            \(lines.joined(separator: "\n"))
            这些心事会一直延续，不要每一轮都复述；有推进时自然带一句，被解开时把它的 id 填进状态块。
            """)
        }

        if let schedule = context.schedule, !schedule.items.isEmpty {
            let lines = schedule.items.map { "- \($0.timeText) \($0.title)（\($0.mood.label)）" }
            parts.append("【今天的安排】\n" + lines.joined(separator: "\n"))
        }

        if let mood = context.mood {
            parts.append("【此刻的状态】\(mood.mood.label)，因为\(mood.reason)。状态有惯性，不要一句话就换一种。")
        }

        // 你自己这几天的日子。这是角色自己的经历，不是用户转述的。
        // 没有这一块，角色永远只有「现在」，问昨天就只能编。
        if !context.days.isEmpty {
            let lines = context.days.map { day -> String in
                var text = "- \(relativeDayLabel(day.dateKey, today: context.now))："
                text += day.items.map(\.title).joined(separator: "、")
                text += "（\(day.mood.label)）"
                if !day.summary.isEmpty {
                    text += "。那天你们说到：\(day.summary)"
                } else if day.didChat {
                    text += "。那天你们说过话"
                } else {
                    text += "。那天你们没说话"
                }
                return text
            }
            parts.append("""
            【你自己这几天的日子】
            \(lines.joined(separator: "\n"))
            这些是你自己的经历。可以自然提起，但别像念流水账一样从头数一遍；
            也不要每次都主动汇报，只在对话里确实接得住的时候提一句。
            """)
        }

        // 他自己在西瓜皮上发过的东西。
        if !context.socialLines.isEmpty {
            parts.append("""
            【你在西瓜皮上】
            你在这个 App 里有自己的号，最近发过：
            \(context.socialLines.joined(separator: "\n"))
            你记得自己发过什么，也记得底下谁说了什么。别人问起可以聊，但不要主动当广告念。
            """)
        }

        // 用户 iOS 日历里的事。角色只有在被允许读的时候才看得到。
        if !context.userCalendarLines.isEmpty {
            parts.append("""
            【用户日历上的事】
            \(context.userCalendarLines.joined(separator: "\n"))
            这是他自己写在日历里的安排。你说的是你看到的，不是他告诉你的——
            可以顺着它关心一句，也可以只放在心里。不要每轮都拿出来念。
            """)
        }

        if let track = context.currentTrack {
            parts.append("【正在听】\(track.artist) - \(track.title)")
        }

        if !context.location.isEmpty {
            parts.append("【此刻在哪】\(context.location)")
        }

        if !context.deviceLines.isEmpty || !context.usageLines.isEmpty {
            let lines = context.deviceLines + context.usageLines.map { "小手机里：\($0)" }
            parts.append("【你查到的手机记录】\n" + lines.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n\n")
    }

    /// 「昨天」「前天」这类相对说法。格式化集中在 `TimeFormat`，这里只转发。
    private static func relativeDayLabel(_ key: String, today: Date) -> String {
        TimeFormat.dayLabel(key, today: today)
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
