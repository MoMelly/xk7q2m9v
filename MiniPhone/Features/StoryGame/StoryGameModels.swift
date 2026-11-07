import Foundation

/// 文游（文字游戏）的数据层。
///
/// 一局故事是一个独立文件，不进 SwiftData：剧情是「玩完就归档」的一次性内容，
/// 唯一需要落库的是结束时按记忆模式回写进角色 `memorySummary` 的那一段。
/// 文件放在 `Documents/stories/`，随沙盒走，重装丢失——要不要进备份等玩过再说。

/// 结束一局时，剧情怎么进入角色的记忆。
enum StoryMemoryMode: String, Codable, CaseIterable, Identifiable {
    /// 角色以为这是和你一起真实发生的事。
    case asReality
    /// 角色完全不知道。
    case hidden
    /// 角色知道这是一起玩的游戏。
    case asGame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .asReality: return "记入剧情"
        case .hidden: return "不记入"
        case .asGame: return "当作游戏"
        }
    }

    var blurb: String {
        switch self {
        case .asReality: return "角色以为这是和你一起做的真实事件"
        case .hidden: return "角色完全不知道发生过"
        case .asGame: return "角色以为这是和你一起玩的游戏"
        }
    }
}

/// 故事里的一行。结构和聊天的解析结果一致，复用 `ReplyParser` 的判定。
struct StoryLine: Codable, Hashable {
    var speaker: String?
    var text: String
    var isNarration: Bool
}

/// 一局文游的完整存档。
struct StorySession: Codable, Identifiable, Hashable {
    var id: UUID
    /// 故事线标题，开局时由模型起，用户可改。
    var title: String
    /// 用户填的故事线描述。
    var premise: String
    /// 参与角色的 uid 与名字（名字冗余一份，角色改名不影响旧档回看）。
    var characterUIDs: [UUID]
    var characterNames: [String]
    var lines: [StoryLine]
    /// 当前待选的行动选项。
    var options: [String]
    /// 走到哪了的滚动摘要，续写与记忆回写都用它。
    var summary: String
    /// 用户是谁（「我的」当前身份名），旁白里按这个称呼玩家。
    var playerName: String
    var createdAt: Date
    var updatedAt: Date
    /// 结束后只读，不再续写。
    var isEnded: Bool

    init(
        title: String,
        premise: String,
        characterUIDs: [UUID],
        characterNames: [String],
        playerName: String
    ) {
        self.title = title
        self.premise = premise
        self.characterUIDs = characterUIDs
        self.characterNames = characterNames
        self.playerName = playerName
        lines = []
        options = []
        summary = ""
        createdAt = Date()
        updatedAt = Date()
        isEnded = false
    }
}

/// 存档读写。一局一个 JSON 文件，索引就是扫目录。
enum StoryArchive {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("stories", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func loadAll() -> [StorySession] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder.decodeWithISODate(StorySession.self, from: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ session: StorySession) {
        let url = directory.appendingPathComponent(session.id.uuidString + ".json")
        guard let data = try? JSONEncoder.encodeWithISODate(session) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func delete(_ session: StorySession) {
        let url = directory.appendingPathComponent(session.id.uuidString + ".json")
        try? FileManager.default.removeItem(at: url)
    }
}

extension JSONEncoder {
    static func encodeWithISODate<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

extension JSONDecoder {
    static func decodeWithISODate<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
