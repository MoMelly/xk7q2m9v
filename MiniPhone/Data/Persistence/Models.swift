import Foundation
import SwiftData

/// 一个可对话的角色。
///
/// 主键刻意叫 `uid` 而不是 `id`：`PersistentModel` 已经提供了 `id`
/// （类型是 `PersistentIdentifier`），再声明一个同名属性会让 `Identifiable`
/// 的解析产生歧义，报错信息还很难懂。
@Model
final class Companion {
    var uid: UUID = UUID()
    var name: String = ""
    /// 头像底色，存预设色名而不是 RGB，换主题时能整体调。
    var avatarTintRaw: String = "mint"
    /// 人设。用户写什么就是什么，不做结构化，避免限制表达。
    var persona: String = ""
    /// 开场白。新建会话时作为第一条消息落库。
    var greeting: String = ""
    var presetRaw: String = RoleplayPreset.daily.rawValue
    var replyLengthRaw: String = ReplyLength.medium.rawValue

    /// 群聊模式：一个角色条目承载多个说话人，靠模型输出里的「名字：」拆分。
    var isGroup: Bool = false
    /// 群聊成员描述，只进提示词。
    var membersNote: String = ""

    /// 主页上的一句话签名。QQ 和朋友圈都有这个位置，空着会显得像张卡片。
    var signature: String = ""
    /// 标签，逗号分隔。主页上排成一行胶囊。
    var tagsRaw: String = ""

    /// NPC 是「简化版角色」：内容少、设定浅，但可以升级成正式角色。
    var isNPC: Bool = false

    /// 允许这个角色读用户的系统日历（今天和明天的几条）。
    /// 默认关：能看别人的日程是一件要被明确交出去的事。
    var canReadCalendar: Bool = false

    var wakeHour: Int = 7
    var sleepHour: Int = 23

    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var lastMessageAt: Date?

    /// 滚动记忆摘要。老消息被压缩成这一段，永远是「很久以前发生过什么」。
    var memorySummary: String = ""
    /// 摘要已经覆盖到这个时间点之前的所有消息。
    var memoryCursor: Date?
    var totalReplies: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.character)
    var messages: [StoredMessage] = []

    init(
        name: String,
        persona: String,
        greeting: String,
        preset: RoleplayPreset = .daily,
        avatarTintRaw: String = "mint",
        replyLength: ReplyLength = .medium,
        isGroup: Bool = false,
        membersNote: String = "",
        wakeHour: Int = 7,
        sleepHour: Int = 23,
        sortIndex: Int = 0
    ) {
        self.uid = UUID()
        self.name = name
        self.persona = persona
        self.greeting = greeting
        self.presetRaw = preset.rawValue
        self.avatarTintRaw = avatarTintRaw
        self.replyLengthRaw = replyLength.rawValue
        self.isGroup = isGroup
        self.membersNote = membersNote
        self.wakeHour = wakeHour
        self.sleepHour = sleepHour
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }

    var preset: RoleplayPreset {
        get { RoleplayPreset(rawValue: presetRaw) ?? .daily }
        set { presetRaw = newValue.rawValue }
    }

    var replyLength: ReplyLength {
        get { ReplyLength(rawValue: replyLengthRaw) ?? .medium }
        set { replyLengthRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            tagsRaw
                .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == " " })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue.joined(separator: ",")
        }
    }

    /// 会话列表里的最后一句预览。
    var lastPreviewText: String {
        guard let last = messages.max(by: { $0.createdAt < $1.createdAt }) else { return "还没有对话" }
        let speaker = last.speaker.map { "\($0)：" } ?? ""
        return speaker + last.text.replacingOccurrences(of: "\n", with: " ")
    }
}

/// 落在库里的一条消息。
///
/// `characterUID` 是冗余字段，但有了它就能用 `#Predicate` 单条件过滤，
/// 不必在谓词里穿过关系，查询计划也更简单。
@Model
final class StoredMessage {
    var uid: UUID = UUID()
    var characterUID: UUID = UUID()
    var roleRaw: String = "user"
    var text: String = ""
    /// 群聊里这句话是谁说的；单聊为空。
    var speaker: String?
    /// 旁白（括号里的动作、场景），渲染成斜体灰字而不是气泡。
    var isNarration: Bool = false
    var createdAt: Date = Date()

    var character: Companion?

    init(
        characterUID: UUID,
        role: ChatMessage.Role,
        text: String,
        speaker: String? = nil,
        isNarration: Bool = false,
        createdAt: Date = Date()
    ) {
        self.uid = UUID()
        self.characterUID = characterUID
        self.roleRaw = role.rawValue
        self.text = text
        self.speaker = speaker
        self.isNarration = isNarration
        self.createdAt = createdAt
    }

    var role: ChatMessage.Role {
        ChatMessage.Role(rawValue: roleRaw) ?? .assistant
    }

    var asChatMessage: ChatMessage {
        ChatMessage(id: uid, role: role, text: text, createdAt: createdAt)
    }
}

/// 角色发的动态，进「照片」App。
@Model
final class MomentPost {
    var uid: UUID = UUID()
    var characterUID: UUID = UUID()
    var characterName: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    /// 决定缩略图渐变的角度，让每条动态看起来不一样。
    var tintSeed: Int = 0

    init(characterUID: UUID, characterName: String, text: String) {
        self.uid = UUID()
        self.characterUID = characterUID
        self.characterName = characterName
        self.text = text
        self.createdAt = Date()
        self.tintSeed = Int.random(in: 0..<360)
    }
}

/// 我自己的备忘录。
///
/// 和「角色记得什么」是两套东西：那部分在角色详情里只读，
/// 这一份是用户自己写的，能改能删。混在一起会让人分不清哪条是自己写的。
@Model
final class NoteItem {
    var uid: UUID = UUID()
    var title: String = ""
    var body: String = ""
    /// 文件夹名，空串归到默认那一组。
    var folder: String = ""
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "", body: String = "", folder: String = "") {
        self.uid = UUID()
        self.title = title
        self.body = body
        self.folder = folder
        self.isPinned = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 列表里显示的第一行。标题为空时退回首行正文，和系统备忘录的规则一致。
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        return firstLine.isEmpty ? "新备忘录" : firstLine
    }

    /// 标题之外剩下的正文，用来做第二行摘要。
    var previewText: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var rest = body
        if !trimmedTitle.isEmpty, rest.hasPrefix(trimmedTitle) {
            rest = String(rest.dropFirst(trimmedTitle.count))
        }
        return rest
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 设定集条目（世界书的简化版）：命中关键词才注入提示词。
@Model
final class WorldEntry {
    var uid: UUID = UUID()
    /// 为空表示全局生效，对每个角色都参与匹配。
    var characterUID: UUID?
    var keywords: String = ""
    var content: String = ""
    var enabled: Bool = true
    var createdAt: Date = Date()

    init(characterUID: UUID?, keywords: String, content: String) {
        self.uid = UUID()
        self.characterUID = characterUID
        self.keywords = keywords
        self.content = content
        self.enabled = true
        self.createdAt = Date()
    }

    var keywordList: [String] {
        keywords
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
