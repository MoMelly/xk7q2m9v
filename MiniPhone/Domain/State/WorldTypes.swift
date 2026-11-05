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

/// 小红书式的一条笔记。
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
    /// 小红书笔记。
    var feed: [FeedNote] = []
    /// 上一轮刷新增量的时间。
    var lastRefreshAt: Date?
    /// 每个页面各自「距上次刷新过了几轮」。key 是 `RefreshPage.rawValue`。
    var refreshTurns: [String: Int] = [:]
    var updatedAt: Date = Date()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, people, schedule, mood, currentTrack, location, usage
        case shopping, forum, shop, feed, lastRefreshAt, refreshTurns, updatedAt
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
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
