import Foundation
import SwiftData

/// 一条消息属于哪个界面。记忆是同一份，显示各自过滤。
enum MessageChannel: String, Codable {
    case chat
    case feedDM
    case feedShare
}

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
    /// 内置头像照片的资源名，形如 `avatar_03`。空表示不用照片。
    ///
    /// 照片和底色并存而不是互斥：照片读不出来（比如换了包、资源被清）
    /// 还能回落到渐变圆加首字，不至于显示一个空白圈。
    var avatarImageKey: String = ""
    /// 用户从相册传的头像文件名，落在 `Documents/avatars`。空表示没传。
    var avatarFileName: String = ""
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

    /// 这个会话里「我」是谁。空表示用默认人设。
    ///
    /// 换身份不换记忆：角色记得的事挂在会话上，人设只决定他以为在跟谁说话。
    var personaUID: String = ""

    /// 西瓜皮里的路人作者：同样共用这套记忆，但不出现在「信息」会话列表。
    var isFeedOnly: Bool = false

    /// 这个角色不能用的表情分组，逗号分隔。空表示所有分组都能用。
    ///
    /// 只在提示词里排除，不删他的历史——表情是「他能不能发」，
    /// 不是「他发过的东西作废」，后者会让旧消息里的图突然变成占位。
    var blockedStickerGroupsRaw: String = ""

    /// 被单独关掉的某个表情的备注名，逗号分隔。
    var blockedStickerNamesRaw: String = ""

    /// 被拍一拍时跟在自己名字后面的那句后缀，比如「的脑门」。
    /// 空串表示用默认的「的肩膀」。
    var patSuffix: String = ""

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
        // 列表是「信息」的，预览只看 chat；私信和转帖归西瓜皮那边显示。
        let mine = messages.filter { $0.channel == .chat }
        guard let last = mine.max(by: { $0.createdAt < $1.createdAt }) else { return "还没有对话" }
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
    /// 界面归属。老消息默认是 chat，加这个字段不需要迁移。
    var channelRaw: String = "chat"
    /// 同一角色可以有多段私信 / 多个转帖，用 threadID 把对话分开。
    var threadRaw: String = ""
    /// 模拟图片的种子，0 表示这条消息没带图。
    /// 图不落文件，靠这个数现画，所以备份里也只是一行整数。
    var imageSeed: Int = 0

    /// 已撤回。文本还留着（导出、排查、模型上下文都要用到），只是界面不显示。
    var isRecalled: Bool = false

    /// 引用的是谁说的、说了什么。两段都空表示这条没引用。
    /// 存文本而不是存消息 id：被引用那条删了，引用块还读得出来。
    var quoteSpeaker: String = ""
    var quoteText: String = ""

    /// 改过的时间。空表示没编辑过。
    var editedAt: Date?

    /// 拍一拍事件。这类行不套气泡，在对话里居中显示一行小字。
    var isPat: Bool = false

    /// 置顶。置顶的消息在顶栏留一条，点一下能滚回去。
    var isPinned: Bool = false

    /// 红包。0 表示这条不是红包。
    ///
    /// 存「分」而不是「元」：金额要参与显示和求和，浮点一路上会掉一分钱。
    var packetCents: Int = 0
    /// 红包封面上的那句话。
    var packetNote: String = ""
    /// 拆没拆。拆了才显示金额，跟真机一样。
    var packetOpened: Bool = false

    var createdAt: Date = Date()

    var character: Companion?

    init(
        characterUID: UUID,
        role: ChatMessage.Role,
        text: String,
        speaker: String? = nil,
        isNarration: Bool = false,
        channel: MessageChannel = .chat,
        threadID: UUID? = nil,
        imageSeed: Int = 0,
        createdAt: Date = Date()
    ) {
        self.uid = UUID()
        self.characterUID = characterUID
        self.roleRaw = role.rawValue
        self.text = text
        self.speaker = speaker
        self.isNarration = isNarration
        self.channelRaw = channel.rawValue
        self.threadRaw = threadID?.uuidString ?? ""
        self.imageSeed = imageSeed
        self.createdAt = createdAt
    }

    var role: ChatMessage.Role {
        ChatMessage.Role(rawValue: roleRaw) ?? .assistant
    }

    var channel: MessageChannel {
        get { MessageChannel(rawValue: channelRaw) ?? .chat }
        set { channelRaw = newValue.rawValue }
    }

    var asChatMessage: ChatMessage {
        // 带图的消息在历史里得说清楚，不然模型会看到一条只有半句话、
        // 或者干脆空白的内容，接不上刚才聊到哪儿。
        var body: String
        if imageSeed > 0 {
            body = text.isEmpty ? "[发了一张图]" : "\(text)（附图）"
        } else {
            body = text
        }
        // 撤回和引用都要让模型知道，否则它会对着一段自己「没说过」的话往下接。
        // 只带一句标记，不复述原文。
        if isRecalled {
            body = "[这条已撤回]"
        }
        if !quoteText.isEmpty {
            body = "（引用\(quoteSpeaker)：\(quoteText.prefix(40))）\(body)"
        }
        return ChatMessage(id: uid, role: role, text: body, createdAt: createdAt)
    }
}

/// 「我」在这部手机里的身份。
///
/// 一个人可以有多个身份：用小号去逗某个角色、换一个名字重新认识同一个人。
/// 身份只决定角色以为在跟谁说话，记忆挂在会话上不跟着换——
/// 换身份不等于换世界，那件事由多存档解决。
@Model
final class UserProfile {
    var uid: UUID = UUID()
    var name: String = "我"
    /// 一句话签名，角色在提示词里能看到。
    var signature: String = ""
    /// 现在的状态，一句话。比签名更「当下」，角色可以顺着提起。
    var statusText: String = ""
    /// 状态上挂的表情备注名。空串表示没挂表情。
    /// 存名字而不是 uid：换设备、重导表情库后名字还能对上。
    var statusStickerName: String = ""
    /// 自我介绍，可以写年龄、职业、跟这个角色什么关系。
    var bio: String = ""
    var tagsRaw: String = ""
    /// 头像底色，和角色一样存色名而不是 RGB。
    var avatarTintRaw: String = "mint"
    /// 内置矢量头像的符号名。空串表示显示名字首字。
    var avatarSymbol: String = ""
    /// 内置头像照片的资源名，形如 `avatar_c01`。优先于符号。
    var avatarImageKey: String = ""
    /// 从相册传的头像文件名。优先于内置照片。
    var avatarFileName: String = ""
    /// 我被人拍的时候，名字后面那句后缀。空串 = 默认的「的头像」。
    var patSuffix: String = ""
    /// 新会话默认用哪个。
    var isDefault: Bool = false
    var createdAt: Date = Date()

    init(
        name: String,
        signature: String = "",
        bio: String = "",
        tagsRaw: String = "",
        avatarTintRaw: String = "mint",
        isDefault: Bool = false
    ) {
        self.uid = UUID()
        self.name = name
        self.signature = signature
        self.bio = bio
        self.tagsRaw = tagsRaw
        self.avatarTintRaw = avatarTintRaw
        self.isDefault = isDefault
        self.createdAt = Date()
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
}

/// 角色发的动态，进「照片」App。
@Model
final class MomentPost {    var uid: UUID = UUID()
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

/// 我自己导入的一本 txt。
///
/// 只存纯文本，不解析排版：txt 里本来就没有排版，硬抽章节遇到格式不规整的
/// 反而会把正文切碎。阅读进度按段落序号存，换字号也不会跑位。
@Model
final class ReadingBook {
    var uid: UUID = UUID()
    var title: String = ""
    var body: String = ""
    /// 读到第几段。段落由换行切出来，天然稳定。
    var paragraphIndex: Int = 0
    var paragraphCount: Int = 0
    var addedAt: Date = Date()
    var lastReadAt: Date?

    init(title: String, body: String) {
        self.uid = UUID()
        self.title = title
        self.body = body
        self.addedAt = Date()
        self.paragraphCount = ReadingBook.split(body).count
    }

    /// 按空行 / 换行切段，去掉全空的段。
    static func split(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var paragraphs: [String] { ReadingBook.split(body) }

    var progress: Double {
        guard paragraphCount > 0 else { return 0 }
        return min(1, Double(paragraphIndex) / Double(paragraphCount))
    }

    /// 列表里的第二行：字数 + 读到百分之几。
    var summary: String {
        let chars = body.count
        let percent = Int((progress * 100).rounded())
        return "\(chars) 字 · 读到 \(percent)%"
    }
}

/// 设定集条目（世界书的简化版）：命中关键词才注入提示词。
///
/// `alwaysOn` 是不靠关键词的那一档：住处、工作、家里有谁这类基本盘，
/// 用户不会每句话都提到关键词，但角色必须一直知道。默认关，老的条目保持原样。
@Model
final class WorldEntry {
    var uid: UUID = UUID()
    /// 为空表示全局生效，对每个角色都参与匹配。
    var characterUID: UUID?
    var keywords: String = ""
    var content: String = ""
    var enabled: Bool = true
    /// 常驻：每轮都进提示词，不看关键词。
    var alwaysOn: Bool = false
    var createdAt: Date = Date()

    init(characterUID: UUID?, keywords: String, content: String, alwaysOn: Bool = false) {
        self.uid = UUID()
        self.characterUID = characterUID
        self.keywords = keywords
        self.content = content
        self.enabled = true
        self.alwaysOn = alwaysOn
        self.createdAt = Date()
    }

    var keywordList: [String] {
        keywords
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
