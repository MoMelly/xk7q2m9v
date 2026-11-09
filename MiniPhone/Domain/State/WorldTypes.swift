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

/// 匿名提问箱里的一问一答。
///
/// 关键在「匿名」：问题不带署名，角色不知道是谁问的，答的时候也就没有
/// 「对谁」这个前提。这跟聊天是两种东西——聊天里他一直在应付你，
/// 提问箱里他是在对一个看不见的人说话，会更坦率一点。
struct AnonymousQuestion: Codable, Identifiable, Hashable {
    var id: UUID
    var characterName: String
    /// 提问箱自己编的代号，比如「匿名 3 号」。用来区分不同的问题，不代表谁。
    var asker: String
    var text: String
    var answer: String
    var askedAt: Date
    var answeredAt: Date?
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
    /// 我今天怎么过。这一份属于**这台手机的使用者**，不按角色分：
    /// 日历里的「我的」页、主屏那块「今天」都是它。角色的日子在 `characterDays`。
    var schedule: DaySchedule?
    /// 每个角色此刻的心情，key 是角色名。
    ///
    /// 原来只有一份，结果跟 A 聊完，A 的心情会出现在跟 B 的提示词里，
    /// 锁屏和主屏组件也跟着换人。心情是「他此刻怎样」，只能挂在人身上。
    var moods: [String: MoodState] = [:]
    var currentTrack: Track?
    /// 每个角色此刻在哪，key 是角色名。原来也只有一份，和心情同一个毛病。
    var locations: [String: String] = [:]
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
    /// 每个角色各一台手机。
    ///
    /// 原来只存一台（`phone`），第二个角色生成时会把第一台覆盖掉——
    /// 有多个角色的时候，查手机只能查到最近说话的那个。
    /// 现在按 `owner` 存一份数组，谁的那台归谁。
    var phones: [CharacterPhone] = []
    /// 每段关系各一份火花，key 是角色名。
    ///
    /// 和手机同一个毛病：只存一份的话，跟 A 说的话会算进跟 B 的火花里。
    var couples: [String: CoupleState] = [:]
    /// 老存档里那唯一一份火花。迁移时归给第一个开口的角色，归完置空。
    var legacyCouple: CoupleState?
    /// 每个角色的好感度，0–100。key 是角色名。
    ///
    /// 不是「分数」而是一个可以手调的刻度：聊天会慢慢推它，用户也能直接拖。
    /// 只进提示词当语气参考，不参与任何数值判定——写成阈值解锁剧情那种，
    /// 一旦数字算错就变成「聊了三百句还是陌生」。
    var affinity: [String: Int] = [:]
    /// 自由变量表。key 是名字，value 是一句话，整张表进提示词。
    ///
    /// 有些事实既不属于哪个角色、也不适合塞进设定集：天气、地点、今天是几号、
    /// 「我们第一次见面是在三月」。它们要的是能被引用，不是被归类。
    var variables: [String: String] = [:]
    /// 匿名提问箱里的一问一答，新的在前。
    var questions: [AnonymousQuestion] = []
    var updatedAt: Date = Date()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, people, schedule, currentTrack, usage
        case shopping, forum, shop, feed, lastRefreshAt, refreshTurns
        case characterDays, letters, updatedAt
        case feedInbox, feedActivity
        case phones, couples
        case moods, locations
        case affinity, variables, questions
        /// 旧字段，只读不写：解出老存档里的那一台手机 / 那一份火花 / 那一份心情 / 那一个地点。
        case phone, couple, mood, location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        people = try container.decodeIfPresent([PersonMemory].self, forKey: .people) ?? []
        schedule = try container.decodeIfPresent(DaySchedule.self, forKey: .schedule)
        // 老存档里的 mood / location 只有一份，没有归属，猜不出是谁的。
        // 心情是半小时就会变的临时状态，与其瞎猜给一个人，不如让它自己重新长出来。
        _ = try container.decodeIfPresent(MoodState.self, forKey: .mood)
        _ = try container.decodeIfPresent(String.self, forKey: .location)
        moods = try container.decodeIfPresent([String: MoodState].self, forKey: .moods) ?? [:]
        locations = try container.decodeIfPresent([String: String].self, forKey: .locations) ?? [:]
        currentTrack = try container.decodeIfPresent(Track.self, forKey: .currentTrack)
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
        // 手机：老存档只有一台，搬进数组；新存档直接读数组。
        let legacyPhone = try container.decodeIfPresent(CharacterPhone.self, forKey: .phone)
        phones = try container.decodeIfPresent([CharacterPhone].self, forKey: .phones)
            ?? legacyPhone.map { [$0] }
            ?? []
        // 火花：老存档只有一份，先挂在 legacyCouple 上，
        // 等知道是谁了（下一次记火花时）再落到那个角色名下。
        couples = try container.decodeIfPresent([String: CoupleState].self, forKey: .couples) ?? [:]
        let legacy = try container.decodeIfPresent(CoupleState.self, forKey: .couple)
        if couples.isEmpty, let legacy, !legacy.myDays.isEmpty || !legacy.theirDays.isEmpty {
            legacyCouple = legacy
        }
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        affinity = try container.decodeIfPresent([String: Int].self, forKey: .affinity) ?? [:]
        variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        questions = try container.decodeIfPresent([AnonymousQuestion].self, forKey: .questions) ?? []
    }

    /// 归档编码要跟着手写解码一起走，两边字段名对不上会静默丢数据。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(people, forKey: .people)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encode(moods, forKey: .moods)
        try container.encodeIfPresent(currentTrack, forKey: .currentTrack)
        try container.encode(locations, forKey: .locations)
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
        try container.encode(phones, forKey: .phones)
        try container.encode(couples, forKey: .couples)
        try container.encode(affinity, forKey: .affinity)
        try container.encode(variables, forKey: .variables)
        try container.encode(questions, forKey: .questions)
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
