import Foundation

/// 人物级记忆的值类型。
///
/// 从 `WorldTypes.swift` 拆出来：那边的 `WorldState` 光是手写的
/// `init(from:)` 就占了两百行，人物记忆这一组又各自有自定义解码，
/// 挤在一起既超行数上限，也很难看出哪几个字段是一块的。
///
/// 这一组共同的约定：全部按**名字**归属，不按会话归属。群聊里发生的事
/// 单聊也读得到，靠的就是这一点。

/// 一条跨会话事实。归属到人，不归属到会话，群聊里发生的事单聊也能读到。
struct PersonFact: Codable, Identifiable {
    var id: UUID
    var text: String
    var sourceName: String
    var createdAt: Date
}

enum VoiceSource: String, Codable {
    case chat
    case moment
    case schedule
}

/// 一条心声。
///
/// 与「单轮给玩家看一句」的区别：它有时间戳、有来源、有是否了结，
/// 后续提示词会读到尚未了结的心结，直到被明确标记解决。
struct InnerVoiceEntry: Codable, Identifiable {
    var id: UUID
    var personName: String
    var text: String
    var createdAt: Date
    var source: VoiceSource
    var isResolved: Bool
    var resolvedAt: Date?
    var lastReferencedAt: Date?
}

struct PersonMemory: Codable, Identifiable {
    var name: String
    var summary: String
    var facts: [PersonFact]
    var voices: [InnerVoiceEntry]
    /// 他在这部手机里跟谁相处出来的这份记忆。空串 = 默认身份。
    ///
    /// 换身份之后是同一个人名、另一个人：两个身份的摘要、事实、心事各存一份。
    /// 不分开的话，新身份开口第一句，他就把旧身份说过的私事全记在身上了。
    var personaUID: String = ""
    /// 他在各个群里各自的那份记忆，key 是群名。
    ///
    /// 和 `summary` 分开存是有意的：群里发生的事不能覆盖掉他一对一的那一份，
    /// 否则在群里聊一晚上，单聊的记忆就整段没了。读的时候拼在一起给模型看，
    /// 但他自己那份「跟他相处过的记忆」始终在原位。
    var groupNotes: [String: String] = [:]

    /// 同一个人名可能有两份（不同身份），所以 id 得带上身份。
    var id: String { "\(name)#\(personaUID)" }

    private enum CodingKeys: String, CodingKey {
        case name, summary, facts, voices, groupNotes, personaUID
    }

    init(
        name: String,
        summary: String,
        facts: [PersonFact],
        voices: [InnerVoiceEntry],
        groupNotes: [String: String] = [:],
        personaUID: String = ""
    ) {
        self.name = name
        self.summary = summary
        self.facts = facts
        self.voices = voices
        self.groupNotes = groupNotes
        self.personaUID = personaUID
    }

    /// 逐字段兜底。`groupNotes` 是后加的：合成解码遇到缺 key 会整份抛错，
    /// 老存档的每一个人都会因此读不出来，整个 `people` 变成空数组。
    /// `personaUID` 同理——老存档解出来是空串，正好就是默认身份。
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        name = try box.decodeIfPresent(String.self, forKey: .name) ?? ""
        summary = try box.decodeIfPresent(String.self, forKey: .summary) ?? ""
        facts = try box.decodeIfPresent([PersonFact].self, forKey: .facts) ?? []
        voices = try box.decodeIfPresent([InnerVoiceEntry].self, forKey: .voices) ?? []
        groupNotes = try box.decodeIfPresent([String: String].self, forKey: .groupNotes) ?? [:]
        personaUID = try box.decodeIfPresent(String.self, forKey: .personaUID) ?? ""
    }

    static func empty(named name: String, personaUID: String = "") -> PersonMemory {
        PersonMemory(name: name, summary: "", facts: [], voices: [], personaUID: personaUID)
    }
}

/// `id` 用相对路径而不是随机 UUID：歌单每次扫描都要保持同一批身份，
