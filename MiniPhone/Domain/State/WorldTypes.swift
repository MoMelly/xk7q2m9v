import Foundation

/// 世界状态的值类型。
///
/// 这一层刻意不依赖 SwiftData：世界状态是跨会话、跨 App 共享的一份快照，
/// 用 Codable 文件存取可以避开 SwiftData 模型变更带来的迁移，
/// 也让备份导出能直接复用同一份结构。

enum Mood: String, Codable, CaseIterable, Identifiable {
    case calm
    case glad
    case focused
    case tired
    case annoyed
    case low
    case excited

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: return "平静"
        case .glad: return "开心"
        case .focused: return "专注"
        case .tired: return "疲惫"
        case .annoyed: return "烦躁"
        case .low: return "低落"
        case .excited: return "兴奋"
        }
    }

    var symbol: String {
        switch self {
        case .calm: return "leaf.fill"
        case .glad: return "sun.max.fill"
        case .focused: return "scope"
        case .tired: return "moon.zzz.fill"
        case .annoyed: return "bolt.fill"
        case .low: return "cloud.rain.fill"
        case .excited: return "sparkles"
        }
    }
}

enum MoodSource: String, Codable {
    case schedule
    case chat
    case manual
}

/// 当前心情。带起因和更新时间，用于判断「该不该变」而不是每轮都变。
struct MoodState: Codable {
    var mood: Mood
    var reason: String
    var updatedAt: Date
    var source: MoodSource
}

struct ScheduleItem: Codable, Identifiable, Hashable {
    var id: UUID
    var hour: Int
    var title: String
    var mood: Mood
    var note: String

    var timeText: String {
        String(format: "%02d:00", hour)
    }
}

struct DaySchedule: Codable {
    var dateKey: String
    var items: [ScheduleItem]
    var generatedAt: Date
}

/// 某个角色某一天的时间轴，也是他这一天留下的记忆。
///
/// 只在「当天和它说过话」时才落一份，不给二十个没聊过的角色白造二十份内容。
/// 落下来之后就留着：角色要能说出「昨天在做什么」，光有今天这一天是不够的。
struct CharacterDay: Codable, Identifiable {
    var name: String
    var dateKey: String
    var items: [ScheduleItem]
    /// 这天的主要心情，取日程里出现最多的一种。
    var mood: Mood
    /// 当天发生的事，由聊天之后的一次概括写进来。没聊过就是空串。
    var summary: String
    /// 这天有没有真的说过话。日程是排出来的，这个标记是聊出来的。
    var didChat: Bool
    var generatedAt: Date

    var id: String { "\(name)|\(dateKey)" }

    private enum CodingKeys: String, CodingKey {
        case name, dateKey, items, mood, summary, didChat, generatedAt
    }

    init(
        name: String,
        dateKey: String,
        items: [ScheduleItem],
        mood: Mood,
        summary: String = "",
        didChat: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.name = name
        self.dateKey = dateKey
        self.items = items
        self.mood = mood
        self.summary = summary
        self.didChat = didChat
        self.generatedAt = generatedAt
    }

    /// 逐字段兜底。这一层以后还会加东西（事件、关系变化），
    /// 合成解码会让任何一次新增都把整份世界状态读废。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        dateKey = try container.decodeIfPresent(String.self, forKey: .dateKey) ?? ""
        items = try container.decodeIfPresent([ScheduleItem].self, forKey: .items) ?? []
        if let raw = try? container.decodeIfPresent(String.self, forKey: .mood),
           let parsed = Mood(rawValue: raw) {
            mood = parsed
        } else {
            mood = .calm
        }
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        didChat = try container.decodeIfPresent(Bool.self, forKey: .didChat) ?? false
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
    }
}

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

    var id: String { name }

    static func empty(named name: String) -> PersonMemory {
        PersonMemory(name: name, summary: "", facts: [], voices: [])
    }
}

/// `id` 用相对路径而不是随机 UUID：歌单每次扫描都要保持同一批身份，
/// 否则 SwiftUI 的 ForEach 会把整列当成换了数据。
struct Track: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var artist: String
    var fileName: String
}

struct AppUsageRecord: Codable {
    var appName: String
    var seconds: TimeInterval
    var lastOpenedAt: Date
}

struct ShoppingItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var price: String
    var status: String
    var orderedAt: Date
}

/// 一条由模型推出来的商品。
///
/// 和上面的 `ShoppingItem` 不是一回事：那个是手写的订单清单，这个是
/// 「按你最近聊到的东西推给你」的候选。`reason` 存的是当时那句话，
/// 界面要把它显示出来——推荐如果不是从聊天里长出来的，就只是普通广告。
struct ShopItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    /// 存分，避免用浮点算钱。
    var priceCents: Int
    /// 一句话推荐语，界面上显示在标题下面。
    var note: String
    /// 从哪句聊天推出来的，空表示这次没给依据。
    var reason: String
    var category: String
    /// 封面配色的种子。同一条商品每次渲染颜色一致。
    var imageSeed: Int
    var addedAt: Date
    var inCart: Bool

    var priceText: String {
        let yuan = priceCents / 100
        let cent = priceCents % 100
        return cent == 0 ? "¥\(yuan)" : String(format: "¥%d.%02d", yuan, cent)
    }
}

struct NoteComment: Codable, Identifiable, Hashable {
    var id: UUID
    var authorName: String
    var text: String
    var postedAt: Date
    /// 角色发的评论和路人发的在界面上要区分开。
    var isCharacter: Bool
}

/// 一封写给你的信。
///
/// 不是聊天记录的长版本：信是一次写完的、有开头和落款、不会秒回。
/// 由角色详情页里「让 TA 写封信」触发，写完就躺在信件里，不会自己消失。
struct Letter: Codable, Identifiable, Hashable {
    var id: UUID
    var fromName: String
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool
    /// 收藏。加了这颗星之后，老存档里没有这个键——解码要容忍缺字段，
    /// 不然一份保存好的世界状态会因为一封信读不出来而整份退回空。
    var isFavorite: Bool

    /// 显式声明一份键表：下面写了自定义解码，靠合成的键表容易两边对不上。
    private enum CodingKeys: String, CodingKey {
        case id
        case fromName
        case title
        case body
        case createdAt
        case isRead
        case isFavorite
    }

    init(
        id: UUID,
        fromName: String,
        title: String,
        body: String,
        createdAt: Date,
        isRead: Bool,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.fromName = fromName
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isRead = isRead
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        fromName = try box.decode(String.self, forKey: .fromName)
        title = try box.decode(String.self, forKey: .title)
        body = try box.decode(String.self, forKey: .body)
        createdAt = try box.decode(Date.self, forKey: .createdAt)
        isRead = try box.decode(Bool.self, forKey: .isRead)
        isFavorite = try box.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

/// 西瓜皮式的一条笔记。
///
/// 封面不是图片文件，是由标题和 `coverSeed` 现场排出来的文字图——
/// 用真图就要么占包体、要么调生图接口，两种都不划算。
struct FeedNote: Codable, Identifiable, Hashable {
    var id: UUID
    var authorName: String
    /// 角色发的笔记带上 uid，用来点进角色主页。
    var authorUID: String?
    var title: String
    var body: String
    var tag: String
    var likes: Int
    var comments: [NoteComment]
    var postedAt: Date
    var coverSeed: Int
}

/// 西瓜皮来件的两种类型。私信和转帖在界面上是两条独立通道，
/// 所以从数据层就分开，不靠「消息里带个帖子 id」混成一种。
enum FeedInboxKind: String, Codable {
    case directMessage
    case postShare
}

/// 角色主动发来的一条：一段私信，或者转一篇帖子加一句附言。
///
/// `threadID` 指向这段对话在 `StoredMessage` 里的那一段；内容本身不另存一份，
/// 否则同一个动作会在聊天记录和记忆里出现两次。
struct FeedInboxItem: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: FeedInboxKind
    /// 和 `FeedNote.authorUID` 一样用字符串，路人作者也能对上。
    var companionUID: String
    var companionName: String
    var noteID: UUID?
    var noteTitle: String
    var noteBody: String
    var noteTag: String
    var coverSeed: Int
    /// 私信正文，或转帖时附的那句话。
    var message: String
    var createdAt: Date
    var isRead: Bool
    var threadID: UUID
}

/// 角色在西瓜皮做过的事。这是唯一进记忆层的记录：
/// inbox 本身不进 systemPrompt，避免角色下次把同一件事说两遍。
struct FeedActivity: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: FeedInboxKind
    var companionName: String
    var summary: String
    var createdAt: Date
}

/// 兼容用的旧结构，只为了让老存档还能解开。新代码不再往里写。
struct ForumPost: Codable, Identifiable {
    var id: UUID
    var author: String
    var title: String
    var body: String
    var postedAt: Date
    var replyCount: Int
}

/// 一份完整快照。所有 App 只读这一份，写入也只走 WorldStore。
///
/// `init(from:)` 是手写的：合成的解码要求每个 key 都存在，只要加一个字段，
/// 老用户的 world-state.json 就整份解不开、全部重置。改成逐字段
/// `decodeIfPresent` 之后，加字段只影响新字段本身。
struct WorldState: Codable {
    var version: Int = 1
    var people: [PersonMemory] = []
    var schedule: DaySchedule?
    var mood: MoodState?
    var currentTrack: Track?
    var location: String = ""
    var usage: [AppUsageRecord] = []
    var shopping: [ShoppingItem] = []
    var forum: [ForumPost] = []
    /// 购物页的推荐流，由刷新引擎写入。
    var shop: [ShopItem] = []
    /// 西瓜皮笔记。
    var feed: [FeedNote] = []
    /// 收到的信。新的在前。
    var letters: [Letter] = []
    /// 西瓜皮收到的私信与转帖。新的在前。
    var feedInbox: [FeedInboxItem] = []
    /// 角色在西瓜皮做过什么，进提示词让记忆层知道。只留最近这些条。
    var feedActivity: [FeedActivity] = []
    /// 上一轮刷新增量的时间。
    var lastRefreshAt: Date?
    /// 每个页面各自「距上次刷新过了几轮」。key 是 `RefreshPage.rawValue`。
    var refreshTurns: [String: Int] = [:]
    /// 各角色当天的时间轴，只保留今天的。
    var characterDays: [CharacterDay] = []
    /// 他的手机里有什么。按角色名换一台，换人时旧的不清，但只有当前角色那台会被读到。
    var phone: CharacterPhone?
    var updatedAt: Date = Date()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, people, schedule, mood, currentTrack, location, usage
        case shopping, forum, shop, feed, lastRefreshAt, refreshTurns
        case characterDays, letters, updatedAt
        case feedInbox, feedActivity
        case phone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        people = try container.decodeIfPresent([PersonMemory].self, forKey: .people) ?? []
        schedule = try container.decodeIfPresent(DaySchedule.self, forKey: .schedule)
        mood = try container.decodeIfPresent(MoodState.self, forKey: .mood)
        currentTrack = try container.decodeIfPresent(Track.self, forKey: .currentTrack)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        usage = try container.decodeIfPresent([AppUsageRecord].self, forKey: .usage) ?? []
        shopping = try container.decodeIfPresent([ShoppingItem].self, forKey: .shopping) ?? []
        forum = try container.decodeIfPresent([ForumPost].self, forKey: .forum) ?? []
        shop = try container.decodeIfPresent([ShopItem].self, forKey: .shop) ?? []
        feed = try container.decodeIfPresent([FeedNote].self, forKey: .feed) ?? []
        lastRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastRefreshAt)
        refreshTurns = try container.decodeIfPresent([String: Int].self, forKey: .refreshTurns) ?? [:]
        characterDays = try container.decodeIfPresent([CharacterDay].self, forKey: .characterDays) ?? []
        letters = try container.decodeIfPresent([Letter].self, forKey: .letters) ?? []
        feedInbox = try container.decodeIfPresent([FeedInboxItem].self, forKey: .feedInbox) ?? []
        feedActivity = try container.decodeIfPresent([FeedActivity].self, forKey: .feedActivity) ?? []
        phone = try container.decodeIfPresent(CharacterPhone.self, forKey: .phone)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// 归档编码要跟着手写解码一起走，两边字段名对不上会静默丢数据。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(people, forKey: .people)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(currentTrack, forKey: .currentTrack)
        try container.encode(location, forKey: .location)
        try container.encode(usage, forKey: .usage)
        try container.encode(shopping, forKey: .shopping)
        try container.encode(forum, forKey: .forum)
        try container.encode(shop, forKey: .shop)
        try container.encode(feed, forKey: .feed)
        try container.encodeIfPresent(lastRefreshAt, forKey: .lastRefreshAt)
        try container.encode(refreshTurns, forKey: .refreshTurns)
        try container.encode(characterDays, forKey: .characterDays)
        try container.encode(letters, forKey: .letters)
        try container.encode(feedInbox, forKey: .feedInbox)
        try container.encode(feedActivity, forKey: .feedActivity)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static let empty = WorldState()

    /// 返回下标而不是结构体副本，避免 Swift 值语义下改了副本没写回去。
    mutating func ensurePerson(named name: String) -> Int {
        if let index = people.firstIndex(where: { $0.name == name }) {
            return index
        }
        people.append(.empty(named: name))
        return people.count - 1
    }

    func person(named name: String) -> PersonMemory? {
        people.first { $0.name == name }
    }

    func unresolvedVoices(limit: Int = 4) -> [InnerVoiceEntry] {
        people
            .flatMap(\.voices)
            .filter { !$0.isResolved }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }
}
