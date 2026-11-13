import Foundation

/// 把角色配置、玩法、设定集、时间拼成一段系统提示词。
///
/// 这一层是「酒馆兼容」的落点：V2 角色卡里的 description / first_mes
/// 直接进 `人设` 和 `开场白`；世界书条目进 `设定集` 的关键词匹配。
/// 剩下的采样参数、正则、宏不暴露给用户，全部由这里固定。
/// 群聊里的一个成员，来自库里同名的 `Companion`。
///
/// 只带名字和一小段人设：群聊提示词的重点是「谁是谁」，不是把
/// 每个人的完整设定都塞进来——那样一轮就要几千字，还互相打架。
struct GroupMate: Hashable {
    let name: String
    let persona: String
    /// 他的角色 uid。设定集条目是按 uid 绑角色的，群聊里要放行各成员的条目。
    let uid: UUID
    /// 此刻的状态。群里每个人都有自己的一天，只给名字的话三个人都活在真空里：
    /// 心情、在哪、今天排了什么。空串表示这一项没有。
    var mood: String = ""
    var location: String = ""
    var schedule: String = ""
    /// 跟你到哪一档。-1 表示还没存过，这句就不写。
    var affinity: Int = -1
    /// 设定集条件条目要按「这个人」判。按群判的话，成员身上带心情、地点、
    /// 认识天数的条目永远不命中——因为群名既没有心情也没有地点。
    var conditions: WorldBookResolver.Conditions?
}

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
        userIdentity: UserIdentity? = nil,
        feedActivityLines: [String] = [],
        stickerNames: [String] = [],
        groupMates: [GroupMate] = []
    ) -> String {
        var blocks: [String] = []

        // 设定先算出来：前置块要插在人设后面，位置定死在装配顺序里，不能算到一半再回头插。
        let book = resolveWorldBook(
            worldEntries,
            character: character,
            triggerText: triggerText,
            worldContext: worldContext,
            now: now,
            groupUIDs: Set(groupMates.map(\.uid)),
            groupMates: groupMates
        )

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

        // 基本设定：放在人设之后。模型对开头最上心，世界观和身份在这里压住整段对话。
        if !book.front.isEmpty {
            blocks.append("""
            【基本设定】
            \(book.front.joined(separator: "\n"))
            这些是不管聊什么都成立的事。不用等被问到才想起来，也不要照着复述。
            """)
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
            // 状态是「现在」的事，和签名那种常设的话分开交代。
            // 提醒一句分寸：可以顺着聊，不能逼着回应。
            let statusText = userIdentity.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !statusText.isEmpty {
                var status = "他现在的状态："
                if !userIdentity.statusStickerName.isEmpty {
                    status += "[表情:\(userIdentity.statusStickerName)] "
                }
                status += statusText
                lines.append(status)
                lines.append("状态是他自己刚设的，想聊就顺着提一两句，别当成他必须解释的事。")
            }
            if userIdentity.isBlank {
                lines.append("你没见过他别的资料。不知道的事就问，不要替他补设定。")
            }
            lines.append("按这个身份跟他说话：称呼、语气、分寸都按你和他现在的关系来。")
            // 这部手机里可以有好几个身份。对角色来说，那是不同的人，
            // 不是同一个人换了名字——不写这一句，模型会拿同一个人的
            // 记忆去接另一个身份的对话，等于把两个人的私事串了。
            lines.append("""
            这部手机里可能还有别人用别的身份来找你。那是另一个人，不是这个人换了个名字、\
            也不是他的小号：不要把两个人的事混在一起，不要跟这个人提另一个人跟你说过什么，\
            也不要拿「上次你不是说……」去接另一个身份的话。
            """)
            blocks.append("【对方是谁】\n" + lines.joined(separator: "\n"))
        }

        // 这两条通道不在这个界面里，但角色得知道自己随时可以用。
        // 不写「要经过对方同意」：主动触达由角色自己决定，界面上没有待确认状态。
        blocks.append("""
        【除了这里，你还能在西瓜皮上做的事】
        你可以自己给我发一条私信，也可以转一篇帖子给我，然后围着那篇帖子跟我聊。
        想发就发，不用先问我，也不用等我说可以。发过什么、聊过什么，你自己记得。
        """)

        if !feedActivityLines.isEmpty {
            blocks.append("【你最近在西瓜皮做过的事】\n" + feedActivityLines.joined(separator: "\n"))
        }

        // 玩法
        blocks.append("【对话形式】\n" + character.preset.promptRules)

        // 表情。只给名字不给图：模型没长眼睛，说「一张猫在翻白眼」比给张图有用。
        if !stickerNames.isEmpty {
            blocks.append("""
            【表情】
            你可以发这些表情：\(stickerNames.joined(separator: "、"))。
            想发就单独占一行写 [表情:名字]，比如 [表情:嫌弃]。
            名字必须从上面这串里挑，不要自己编，也不要把名字写进句子里。
            别每句都发，一次只发一个，情绪到了才用。
            """)
        }

        // 图。只给类型不给图本身：画面是按种子现画的，模型看不到，
        // 所以让它用一句说明来点名要哪一种。
        blocks.append("""
        【图】
        你可以发图，能发的只有这八种：黄昏、雨窗、夜空、咖啡、猫、海、云、灯串。
        想发就单独占一行写 [图:说明]，说明里带上其中一种，比如 [图:窗外的雨] 或 [图:楼下的猫]。
        一次最多一张，别连着发；没什么可说的时候不用硬发。
        """)

        // 群聊
        if character.isGroup {
            let members = character.membersNote.trimmingCharacters(in: .whitespacesAndNewlines)
            var groupText = """
            【这是群聊】成员包括\(members.isEmpty ? "你和其他几位" : members)。
            - 每条回复里，每句话单独一行，以「名字：」开头，名字必须是上述成员之一。
            - 一次可以有一到三个人说话，像真的群聊那样有人接话、有人不接。
            - 不要写旁白，不要写谁在做什么动作，只写台词。
            """
            // 成员各自的设定。只给一串名字的话，模型分不出这些名字是谁，
            // 只好用同一个语气写所有人——群聊看着就像只有一个人在说话。
            //
            // 「此刻」这一行也是同理：没有它，三个人都活在真空里，谁都没有
            // 自己的一天，聊起来只会围着用户的话转。
            if !groupMates.isEmpty {
                let lines = groupMates.map { mate -> String in
                    let head = "- \(mate.name)："
                        + (mate.persona.isEmpty
                            ? "（没写具体设定，按名字和台词保持自己的语气）"
                            : mate.persona)
                    var state: [String] = []
                    if !mate.mood.isEmpty { state.append("心情\(mate.mood)") }
                    if !mate.location.isEmpty { state.append("人在\(mate.location)") }
                    if !mate.schedule.isEmpty { state.append("今天：\(mate.schedule)") }
                    if mate.affinity >= 0 {
                        state.append("跟你\(AffinityScale.stage(of: mate.affinity).label)")
                    }
                    guard !state.isEmpty else { return head }
                    return head + "\n  此刻：" + state.joined(separator: "，")
                }
                groupText += "\n【群成员各自是什么人】\n" + lines.joined(separator: "\n")
                groupText += "\n「此刻」是各人自己的状态，谁的事只归谁。"
            }
            blocks.append(groupText)
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

        // 记忆统一走下面的世界状态块。
        //
        // 这里原来还单独拼一段 `character.memorySummary`，和世界状态块里
        // 「共同记得的事」是同一份文本，等于把记忆写了两遍；群聊时更糟——
        // 那是群主自己单聊的记忆，塞进来会让群里其他人以为那些事发生在群里。
        // 只有完全拿不到世界状态时才退回会话自带的那一份。
        if worldContext == nil {
            let memory = character.activeMemorySummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !memory.isEmpty {
                blocks.append("【你记得的往事】\n" + memory)
            }
        }

        // 跨会话世界状态：人物记忆、心声、日程、心情、设备快照。
        if let worldContext {
            let block = worldBlock(worldContext)
            if !block.isEmpty {
                blocks.append(block)
            }
        }

        // 设定集分两个位置。前置跟在人设后面——模型对越靠前的内容越上心，
        // 世界观、身份这类绝不能搞错的事放这里；补充放尾部，不抢开头的注意力。
        if !book.back.isEmpty {
            blocks.append("""
            【补充设定】
            \(book.back.joined(separator: "\n"))
            这些是补充细节。接得住就用，接不住不用硬塞。
            """)
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
            blocks.append(character.isGroup ? groupMetaBlock : soloMetaBlock)
        }

        if let refresh {
            blocks.append(refreshBlock(refresh))
        }

        return blocks.joined(separator: "\n\n")
    }

    // 两段状态块（`soloMetaBlock` / `groupMetaBlock`）和 `feedActivityLines`
    // 都在 `PromptBuilder+Meta.swift`：那两块是整段固定文本，塞在这里会把
    // 文件顶过 600 行上限。这里只剩调用点。

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
    ///
    /// 这一整块的性质是「你已经知道的事」，不是用户刚说的话。所以开头先交代一句，
    /// 否则模型会拿它当新信息回应——「哦，你养猫啊」这种失忆式回答就是这么来的。
    private static func worldBlock(_ context: WorldContext) -> String {
        var parts: [String] = []

        var memoryLines = context.summaries
        memoryLines.append(contentsOf: context.facts.map { "- \($0.text)" })
        if !memoryLines.isEmpty {
            parts.append("""
            【共同记得的事】
            \(memoryLines.joined(separator: "\n\n"))
            这些是你已经知道的，不需要他再讲一遍。聊到相关的就顺着用；他记错了可以纠正。

            群聊时上面会分成几段、各自顶着一个名字，那表示那一段只有那个人自己知道。
            你替谁说话，就只用谁那一段——不要拿别人的记忆去说别人的事，
            也不要替人回忆他根本没讲过的东西。
            标着「在某某群里」的是群里的共同经历，大家都能提；但别主动把群里的对话搬到另一个场合去讲。
            """)
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

        // 他所在的群里发生过什么。
        //
        // 这一块由 `WorldContext.summaries` 承担：单聊时 `WorldStore` 会把他
        // 各群的记忆拼在每个人那一行后面，群聊时只拼当前这个群的。这里不再
        // 单独列一块，避免同一件事在提示词里出现两次。

        if let schedule = context.schedule, !schedule.items.isEmpty {
            let lines = schedule.items.map { "- \($0.timeText) \($0.title)（\($0.mood.label)）" }
            parts.append("【今天的安排】\n" + lines.joined(separator: "\n"))
        }

        if let mood = context.mood {
            parts.append("【此刻的状态】\(mood.mood.label)，因为\(mood.reason)。状态有惯性，不要一句话就换一种。")
        }

        // 关系刻度。只给语气，不给数字——写出 72 分，模型会开始表演「我们是 72 分的关系」。
        if let affinity = context.affinity {
            let stage = AffinityScale.stage(of: affinity)
            parts.append("""
            【你们现在的关系】\(stage.label)
            \(stage.line)
            按这个分寸说话，不要提「好感度」这三个字，也不要拿它当话题。
            """)
        }

        // 自由变量。整张表都进，因为它们被设计成「一句话说得完」。
        if !context.variables.isEmpty {
            let lines = context.variables.map { "- \($0.key)：\($0.value)" }
            parts.append("【世界变量】\n" + lines.joined(separator: "\n"))
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

        // 你自己手机里的东西。他随时会翻——被问起时不能答「什么手机」。
        if !context.phoneLines.isEmpty {
            parts.append("""
            【你自己手机里的事】
            \(context.phoneLines.joined(separator: "\n"))
            这是你自己的手机，上面都是你留过的东西。他翻到了问起来，你认得，也可以解释；
            但别主动一条条报出来，更不要在没人问的时候自曝。
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

        // 寄出去的信。写过的东西要认得，被问「你上次写那封」不能反问我写过吗。
        if !context.letterLines.isEmpty {
            parts.append("""
            【你写过的信】
            \(context.letterLines.joined(separator: "\n"))
            这些是你亲手写的，内容你自己记得。他不提就别主动追着问「看了没有」。
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

        // 一起听：他按过邀请，你们这会儿在同一条音轨上。
        // 没有这个状态就一句都不写——一个人放歌不该变成角色知道的事，
        // 跟别人一起听更不该让这个人知道。
        if let track = context.listeningNow {
            parts.append("""
            【你们在一起听】
            \(track.artist) - \(track.title)
            是他邀请你一起听的，这会儿两边放的是同一首。你可以顺着歌词或者歌里的情绪接一句，
            像两个人共用一副耳机；但不要每轮都问「好听吗」，也别装成自己刚发现这首歌。
            """)
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

    /// 把设定集解析成两组文本。
    ///
    /// 条件条目要看的是「现在是什么状态」，所以心情和地点从 `worldContext` 里取——
    /// 那一份才是这一轮真正会写进提示词的值，另开一条路去读世界状态会和它对不上。
    private static func resolveWorldBook(
        _ entries: [WorldEntry],
        character: Companion,
        triggerText: String,
        worldContext: WorldContext?,
        now: Date,
        groupUIDs: Set<UUID> = [],
        groupMates: [GroupMate] = []
    ) -> WorldBookResolver.Resolved {
        let conditions = WorldBookResolver.Conditions.build(
            hour: CharacterClock.calendar.component(.hour, from: now),
            mood: worldContext?.mood?.mood,
            location: worldContext?.location ?? "",
            since: character.createdAt,
            now: now
        )
        // 群成员的条目按各自的状态判。成员没带条件时退回这一轮的条件，
        // 所以单聊和「群主自己的条目」走的是同一条老路。
        var memberConditions: [UUID: WorldBookResolver.Conditions] = [:]
        for mate in groupMates {
            guard let scoped = mate.conditions else { continue }
            memberConditions[mate.uid] = scoped
        }
        return WorldBookResolver.resolve(
            entries: entries,
            character: character,
            triggerText: triggerText,
            conditions: conditions,
            groupUIDs: groupUIDs,
            memberConditions: memberConditions
        )
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

    // MARK: - 匿名提问箱

    static let anonymousAnswerSystem = """
    你在替一个角色回答一条匿名提问。
    用第一人称，就像随口答的那样；不用客套，不用「这个问题很好」。
    不写旁白、不加标题、不用 Markdown。
    不要问对方是谁，也不要猜是谁问的——提问箱里本来就是看不见人的。
    不要提到自己在被谁要求回答。
    """

    /// 匿名作答的正文。记忆照给，但明确说「你不知道这些事是谁告诉你的」——
    /// 否则模型会把「跟你聊天时记住的事」和「这个匿名的人」混成一件事。
    static func anonymousAnswerPrompt(
        character: Companion,
        memoryLines: [String],
        question: String
    ) -> String {
        var parts: [String] = []
        let persona = character.persona.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append("【你是谁】\n" + (persona.isEmpty ? "角色名：\(character.name)。" : persona))

        if !memoryLines.isEmpty {
            parts.append("""
            【你记得的事】
            \(memoryLines.joined(separator: "\n"))
            这些都发生过。但提问的人是谁你不知道——可以提这些事，不要说「你上次」。
            """)
        }

        parts.append("【问题】\n\(question)")
        parts.append("两三句话说清，最长不超过五行。")
        return parts.joined(separator: "\n\n")
    }
}
