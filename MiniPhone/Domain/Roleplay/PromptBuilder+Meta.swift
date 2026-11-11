import Foundation

/// 状态块的两段固定文案，以及「他在西瓜皮做过什么」那几行。
///
/// 从 `PromptBuilder` 拆出来的原因很实在：那边加了群成员「此刻」之后顶到 609 行，
/// 撞上了 600 行硬上限。这两段本来就只是整段文本，和拼装逻辑没有耦合。
extension PromptBuilder {

    /// 一对一时用的状态块。心事可以长一点，因为只有一个人在说。
    static let soloMetaBlock = """
    【附加状态块】
    正文之后另起一行，输出一段机器可读的 JSON，以 <<<meta>>> 开头、<<<end>>> 结尾。
    字段全部可选：mood（calm/glad/focused/tired/annoyed/low/excited）、moodReason、
    voice（这一轮没说出口的一句心里话）、memory（这一轮新记住的一个事实）、
    dayLog（这一轮聊完之后，用一句「今天」视角的话概括你们说了什么，25 字内）、
    scheduleNote、moment（一条可以发出去的动态）、voiceResolvedID（某个心结被解开了就填它的 id）。
    只有确实发生了变化才填对应字段，没有就输出 {}。
    正文里不要提到这个块，也不要把它写进台词。
    """

    /// 群聊用的状态块。
    ///
    /// 和一对一那一版有三处硬性差别，都是被实测出来的：
    /// 心事必须点名归属，否则一律落到群主头上，别人永远没有自己的心事；
    /// 心事必须短，一个人一句潜台词，三条心事堆在一起群里就成了内心戏现场；
    /// 群里不产动态——动态是「一个人的号」，一群人不共用一个号。
    static let groupMetaBlock = """
    【附加状态块】
    正文之后另起一行，输出一段机器可读的 JSON，以 <<<meta>>> 开头、<<<end>>> 结尾。
    字段全部可选：
    - mood：这一轮整体是什么气氛（calm/glad/focused/tired/annoyed/low/excited）。
    - moodReason：一句话说明因为什么。
    - voice：心事只写给这一轮真的说了话的人，一句话，格式是「名字：一句没说出口的潜台词」，
      20 字以内，最多两条。没开口的人不要写。写成「阿岚：其实想留他吃饭」这种。
    - memory：这一轮里新出现的、以后还用得上的一个事实（30 字以内）。
    - dayLog：聊完之后用一句「今天」视角的话概括，25 字内。
    - scheduleNote、voiceResolvedID 同平时。
    群里不产出动态，不要填 moment。
    只有确实发生了变化才填对应字段，没有就输出 {}。
    正文里不要提到这个块，也不要把它写进台词。
    """

    /// 把「这个角色在西瓜皮做过什么」压成几行，聊天和私信共用。
    ///
    /// 只取本人、只取最近五条：inbox 全量塞进提示词会把当前对话挤掉，
    /// 别人的活动也不该由他来记得。
    static func feedActivityLines(state: WorldState, characterName: String) -> [String] {
        let recent = state.feedActivity
            .filter { $0.companionName == characterName }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .reversed()
        return recent.map { item in
            let label = item.kind == .postShare ? "转了一篇帖子" : "发了一条私信"
            return "\(label)：\(item.summary)"
        }
    }
}
