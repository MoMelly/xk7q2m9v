import Foundation

/// 手动刷新的提示词。
///
/// 手动刷新是一次独立的请求：不挂在聊天上，用户点一下就要一整屏新内容。
/// 和聊天里那轮「顺便刷新」的区别在数量——那边一轮只塞两三条，因为正文才是主角；
/// 这里整条回复都拿来出内容，所以一次给八条。
extension PromptBuilder {
    static let pageRefreshSystem = """
    你在一部虚构的手机里，替用户刷两个页面：西瓜皮（图文笔记社区）和购物。
    你写的东西会被直接排进页面，用户看到的就是你写的，看不到你。
    只输出机器可读的内容，不写解释、不写开场白、不评价自己在做什么。
    """

    /// 刷新某个页面时要模型产出的东西。
    ///
    /// - Parameters:
    ///   - noteCount: 一次要几条笔记。双列瀑布流一屏大概六到八张。
    ///   - existingTitles: 已经在页面上的标题，用来避免刷出重复内容。
    static func pageRefreshPrompt(
        page: RefreshPage,
        state: WorldState,
        noteCount: Int = 8,
        shopCount: Int = 8,
        existingTitles: [String] = [],
        now: Date = Date()
    ) -> String {
        var blocks: [String] = []

        blocks.append("【现在的世界】\n" + worldSummary(state, now: now))

        switch page {
        case .feed:
            var feed = """
            【这一屏要什么】
            给西瓜皮刷 \(noteCount) 条笔记。这是普通人在用的图文社区：有生活记录、有吐槽、
            有随手拍、有小经验，不是营销号，也不要每条都在讲同一个话题。
            - title：12~20 字，像人随手起的标题，可以带数字或情绪，不要书名号。
            - body：30~60 字，一两句话，具体到某一件事或某个瞬间，不要空话。
            - tag：2~5 个字的话题词，不要带 #。
            - author：发帖人的网名，两三个字，像真 ID；八条里至少五个人不同。
            - comments：可选，0~2 句底下的人说的话，每句 15 字内，语气随便。
            内容可以围绕用户最近聊到的事、这个季节、这个时段，但不要每条都硬扯上用户。
            """
            if !existingTitles.isEmpty {
                let titles = existingTitles.prefix(6).map { "「\($0)」" }.joined(separator: "、")
                feed += "\n不要和这些已经发过的重复：\(titles)"
            }
            blocks.append(feed)

            if !existingTitles.isEmpty {
                blocks.append("""
                【顺手补几条评论】
                feedComments 给 0~3 条，title 原样照抄上面其中一个标题，author 写留言的人，
                text 一句话 30 字内。像隔了一阵才刷到，不要复读原帖。
                """)
            }

        case .shop:
            blocks.append("""
            【这一屏要什么】
            给购物页刷 \(shopCount) 件商品。用户是普通学生，价格几十到一百多。
            - title：商品名，14 字内，具体到型号或口味。
            - price：数字，单位元。
            - note：一句推荐语，20 字内，可以有情绪。
            - reason：为什么推给它，30 字内，可以引用用户说过的话；没有依据就写季节或场景。
            - category：一个词，从「数码 / 吃的 / 日用 / 书 / 穿的」里选。
            八件里不要出现同一类超过三件，也不要全是他已经买过的东西。
            """)
        }

        blocks.append(outputBlock(page: page))
        return blocks.joined(separator: "\n\n")
    }

    /// 要求模型输出成一段可解析的 JSON。
    ///
    /// 用标签而不是裸 JSON：`ReplyEnvelope` 认得这个标签，手动刷新和聊天走同一条解析路径，
    /// 出错时的兜底、裸 JSON 兼容、单条坏掉的容错全都不用重写一遍。
    private static func outputBlock(page: RefreshPage) -> String {
        let payload = page == .feed
            ? """
              {"feed":[{"title":"…","body":"…","tag":"…","author":"…","comments":["…"]}],\
              "feedComments":[{"title":"…","author":"…","text":"…"}]}
              """
            : """
              {"shop":[{"title":"…","price":39.9,"note":"…","reason":"…","category":"日用"}]}
              """

        return """
        【输出格式】
        只输出下面这一段，前后不要任何文字、不要代码块围栏：
        \(ReplyEnvelope.openTag)
        \(payload)
        \(ReplyEnvelope.closeTag)
        """
    }

    /// 世界状态的一段普通话描述，给刷新用。
    ///
    /// 不给完整人设：刷新不需要知道「你是谁」，只需要知道现在几点、什么季节、
    /// 这个人大概在过什么日子，写出来的东西才不会像凭空生成的广告。
    private static func worldSummary(_ state: WorldState, now: Date) -> String {
        var lines: [String] = []
        lines.append("现在：" + CharacterClock.fullDescription(now))

        if let mood = state.mood {
            lines.append("心情：\(mood.mood.label)" + (mood.reason.isEmpty ? "" : "（\(mood.reason)）"))
        }

        let location = state.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty {
            lines.append("地点：\(location)")
        }

        if let schedule = state.schedule, !schedule.items.isEmpty {
            let near = schedule.items
                .filter { $0.hour <= Calendar.current.component(.hour, from: now) }
                .suffix(2)
                .map { "\($0.timeText) \($0.title)" }
            if !near.isEmpty {
                lines.append("今天的安排：" + near.joined(separator: "、"))
            }
        }

        return lines.joined(separator: "\n")
    }
}
