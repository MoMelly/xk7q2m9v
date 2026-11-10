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

/// 玩家在故事里攒出来的倾向。
///
/// 三档而不是几十个变量：分支要能被玩家自己看出来，藏在后台的十维向量
/// 只会让结局显得随机。每次做选择按词表给三档加分，谁高就是谁。
enum StoryBranch: String, Codable, CaseIterable, Identifiable {
    /// 靠近、照顾、退让。
    case gentle
    /// 直接、对抗、冒险。
    case bold
    /// 回避、旁观、沉默。
    case evasive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: return "靠过去"
        case .bold: return "顶上去"
        case .evasive: return "退开"
        }
    }

    /// 结局名。三个档各一套说法，够用，也不用让模型再生成一次。
    var endingTitle: String {
        switch self {
        case .gentle: return "留下的人"
        case .bold: return "先开口的人"
        case .evasive: return "走出去的人"
        }
    }

    var endingLine: String {
        switch self {
        case .gentle: return "你一直在往对方那边靠，事情最后落在一个不吵不闹的地方。"
        case .bold: return "你一路都在把话摆到桌面上，结局不温柔，但干净。"
        case .evasive: return "你几次都选择了不接，故事停在一个没人说破的位置。"
        }
    }

    /// 词表。命中一个加一分，不区分轻重——
    /// 权重一细化就得开始调参，这一层不值得。
    var keywords: [String] {
        switch self {
        case .gentle:
            return ["抱", "安慰", "留", "陪", "等", "温", "笑", "拉", "握", "道谢", "轻轻", "原谅", "退让", "退一步", "说清"]
        case .bold:
            return ["走", "推", "砸", "喊", "冲", "拒", "顶", "反问", "质问", "挑明", "打断", "站起", "抢", "闯", "逼"]
        case .evasive:
            return ["不说", "沉默", "转身", "离开", "装", "避开", "借口", "岔开", "算了", "假装", "低头", "不管", "看着"]
        }
    }
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
    /// 玩家做过的每一个选择。分支变量就是从这里算出来的，
    /// 存原文而不是只存分数：分数算错了还能重算，原文删了就没了。
    var choices: [String]?
    /// 三档倾向的分数。可选，老存档没有这个键也能解开。
    var branchScore: [String: Int]?
    /// 结束时的结局名。没结束是 nil。
    var endingLabel: String?

    init(
        title: String,
        premise: String,
        characterUIDs: [UUID],
        characterNames: [String],
        playerName: String
    ) {
        id = UUID()
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
    // 备份要把 stories/ 整目录拷走，所以这里不能是 private。
    static var directory: URL {
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
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder.decodeWithISODate(StorySession.self, from: data)
            }
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

extension StorySession {
    /// 记一次选择，顺手把三档分数重算一遍。
    ///
    /// 每次重算而不是增量加：词表改了之后旧档的分也能跟上，
    /// 不然老存档会永远停在改表之前的算法上。
    mutating func registerChoice(_ text: String) {
        var all = choices ?? []
        all.append(text)
        choices = all
        branchScore = Self.score(all)
    }

    static func score(_ choices: [String]) -> [String: Int] {
        var tally: [String: Int] = [:]
        for branch in StoryBranch.allCases {
            var value = 0
            for choice in choices {
                for keyword in branch.keywords where choice.contains(keyword) {
                    value += 1
                }
            }
            tally[branch.rawValue] = value
        }
        return tally
    }

    func score(of branch: StoryBranch) -> Int {
        branchScore?[branch.rawValue] ?? 0
    }

    /// 目前最明显的那一档。一个选择都没有、或者谁都没命中时返回 nil。
    var dominantBranch: StoryBranch? {
        guard let branchScore,
              let top = branchScore.max(by: { $0.value < $1.value }),
              top.value > 0
        else { return nil }
        return StoryBranch(rawValue: top.key)
    }
}
