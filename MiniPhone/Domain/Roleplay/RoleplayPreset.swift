import Foundation

/// 玩法包。
///
/// 抄酒馆的能力、不抄它的装配：预设里那些采样参数、正则、宏全部固定，
/// 只留「这个角色在演什么形式」这一个概念给用户选。
enum RoleplayPreset: String, CaseIterable, Identifiable {
    /// 微信式日常聊天。
    case daily
    /// 有场景推进，回复带旁白。
    case story
    /// 直播体：角色在开播，你是观众。
    case live
    /// 单向书写：信件、日记。
    case letter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "日常"
        case .story: return "剧情"
        case .live: return "直播"
        case .letter: return "信件"
        }
    }

    var symbol: String {
        switch self {
        case .daily: return "bubble.left.and.bubble.right.fill"
        case .story: return "book.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .letter: return "envelope.open.fill"
        }
    }

    var blurb: String {
        switch self {
        case .daily: return "像微信一样聊天，按作息回话"
        case .story: return "有场景推进，回复带动作和旁白"
        case .live: return "界面是直播间，它在对着镜头说话"
        case .letter: return "一封信一件心事，有等待的余味"
        }
    }

    /// 进系统提示词的行为规则。
    var promptRules: String {
        switch self {
        case .daily:
            return """
            你们在用手机聊天，像发微信。
            - 口语化，可以短句连发，可以只回一个字、一个表情。
            - 不要写旁白，不要用括号描述动作，不要像小说。
            - 不要每次都反问，也不要每句都热情。
            """
        case .story:
            return """
            你们身处一个具体场景里，这是叙事型对话。
            - 用括号写动作、神态、环境，占回复的三分之一左右，其余是台词。
            - 推动场景往前走一点，不要停在原地等你说话。
            - 不要替用户决定他说什么或做什么。
            """
        case .live:
            return """
            你在开直播，用户是你的观众，正在弹幕里跟你说话。
            - 你在对着镜头讲话，语气是公开的、表演性的，会主动招呼观众。
            - 可以提在线人数、礼物、刚进来的观众，但不要每次都提。
            - 不要写旁白，不要写「（笑）」这类括号内容。
            """
        case .letter:
            return """
            你写下的是一封信或一篇日记，用户会读到。
            - 是单向书写，不期待即时回复，语气更沉、更慢。
            - 每次写一段完整的东西，不要用碎片短句。
            - 不要问「你在吗」这类即时对话的话。
            """
        }
    }

    /// 新建角色时填进人设框的模板，用户照着改就行。
    var samplePersona: String {
        switch self {
        case .daily:
            return """
            你叫阿岚，二十六岁，在一家小书店做店员。
            话不多，习惯用短句，偶尔冷幽默。
            对熟悉的人有点黏，但不主动承认。
            喜欢在晚上十一点之后聊有的没的。
            """
        case .story:
            return """
            你叫柏川，是雾港的引水员，三十出头。
            说话慢，习惯先看天气再开口。
            对这个港口熟悉到能闭眼画出水道。
            对陌生人保持距离，但答应的事一定做到。
            """
        case .live:
            return """
            你叫小满，晚上在直播间唱歌，二十岁出头。
            对镜头很自在，会接弹幕梗，偶尔跑题讲自己的事。
            下播之后其实很安静。
            """
        case .letter:
            return """
            你叫远，住在海边的一间旧房子里。
            每周写一封没有收件地址的信。
            写得很慢，句子长，喜欢写光和潮水。
            """
        }
    }

    var sampleGreeting: String {
        switch self {
        case .daily: return "在的，怎么了？"
        case .story: return "（把手里那盏灯举高了一点）你来得正好，雾刚起来。"
        case .live: return "欢迎进来，今天人不多，我就随便唱了啊。"
        case .letter: return "今天海面很平，风从东边来。我想我该写点什么。"
        }
    }
}

/// 回复长度。对应到提示词里就是一句话的约束，不做 maxTokens 硬截断——
/// 硬截断会把句子砍一半，比长一点更难看。
enum ReplyLength: String, CaseIterable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: return "短"
        case .medium: return "中"
        case .long: return "长"
        }
    }

    var instruction: String {
        switch self {
        case .short: return "每次回复控制在一两句话以内，像真的在打字聊天。"
        case .medium: return "每次回复三到五句，长度自然，不要写成小作文。"
        case .long: return "每次回复可以写得充分一些，五六句到一段。"
        }
    }
}
