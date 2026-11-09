import Foundation

/// 世界书的三个判断：什么时候把这条设定送进提示词。
///
/// 常驻和关键词是原来就有的两档；条件这一档补的是「时间、心情、地点、认识多久」这类
/// 不由聊天内容决定的状态。比如「他夜里不太愿意提工作」——用户一晚上都没说「工作」两个字，
/// 但角色该知道这件事，这就是关键词做不到、常驻又太浪费的那一格。
enum WorldTrigger: String, Codable, CaseIterable, Identifiable {
    case constant
    case condition
    case keyword

    var id: String { rawValue }

    var label: String {
        switch self {
        case .constant: return "常驻"
        case .condition: return "条件"
        case .keyword: return "关键词"
        }
    }

    /// 列表里那一行小字。
    var shortHint: String {
        switch self {
        case .constant: return "每轮都在"
        case .condition: return "状态对上才出现"
        case .keyword: return "提到才想起"
        }
    }
}

/// 设定塞进提示词的位置。
///
/// 模型对越靠前的内容注意力越高，所以这不是排版偏好，是真的会改变结果：
/// 世界观、身份这类必须压住整段对话的内容放前置；补充细节放尾部，不抢开头。
enum WorldPosition: String, Codable, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: return "前置"
        case .back: return "补充"
        }
    }

    var hint: String {
        switch self {
        case .front: return "跟在人设后面。模型读得最认真，适合身份、世界观、绝不能搞错的事。"
        case .back: return "放在输出要求前面。适合细节和补充说明，不抢开头的注意力。"
        }
    }
}

/// 一天里的四段。条件条目按这个判断「现在算不算那个时间」。
///
/// 边界取整点而不是按角色作息算：设定写的是「夜里」，不是「他睡了之后」——
/// 作息每改一次，条件条目就全错位了，那不叫设定。
enum DayPhase: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: return "早上"
        case .afternoon: return "下午"
        case .evening: return "傍晚"
        case .night: return "夜里"
        }
    }

    var hourRange: String {
        switch self {
        case .morning: return "05–11"
        case .afternoon: return "11–17"
        case .evening: return "17–22"
        case .night: return "22–05"
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .morning: return (5..<11).contains(hour)
        case .afternoon: return (11..<17).contains(hour)
        case .evening: return (17..<22).contains(hour)
        case .night: return hour >= 22 || hour < 5
        }
    }

    static func of(hour: Int) -> DayPhase {
        DayPhase.allCases.first { $0.contains(hour: hour) } ?? .night
    }

    static func of(_ date: Date) -> DayPhase {
        of(hour: CharacterClock.calendar.component(.hour, from: date))
    }
}
