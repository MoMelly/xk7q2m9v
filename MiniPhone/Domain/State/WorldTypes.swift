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

struct ForumPost: Codable, Identifiable {
    var id: UUID
    var author: String
    var title: String
    var body: String
    var postedAt: Date
    var replyCount: Int
}

/// 一份完整快照。所有 App 只读这一份，写入也只走 WorldStore。
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
    var updatedAt: Date = Date()

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
