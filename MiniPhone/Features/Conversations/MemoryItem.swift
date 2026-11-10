import Foundation

/// 一条记忆。
///
/// 事实、概括、心事、某个日子，原本是四种结构、四套展示，
/// 编辑器只做了一半（只有「长按删掉」）。这里把它们统一成一种条目：
/// 一行文字加一个来源，一种编辑器改所有。
///
/// 值类型而不是直接改底层：条目要在列表里排序、筛选、比较，
/// 底层那四个结构各有各的 id 规则，摊在视图里就变成四份 if。
struct MemoryItem: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case fact
        case voice
        case summary
        case day

        var id: String { rawValue }

        var label: String {
            switch self {
            case .fact: return "事实"
            case .voice: return "心事"
            case .summary: return "概括"
            case .day: return "日子"
            }
        }

        var symbol: String {
            switch self {
            case .fact: return "pin.fill"
            case .voice: return "bubble.left"
            case .summary: return "text.alignleft"
            case .day: return "calendar"
            }
        }
    }

    /// 稳定 id。底层换了 id（比如自动压缩重建了事实）也不会让列表跳。
    let id: String
    let kind: Kind
    let text: String
    let createdAt: Date
    /// 心事专用：还没放下。
    let isOpen: Bool
    /// 第二行那点小字：来源或附加说明。
    let source: String

    /// 回写时用的定位符。
    let factID: UUID?
    let voiceID: UUID?
    let dateKey: String

    init(
        id: String,
        kind: Kind,
        text: String,
        createdAt: Date,
        isOpen: Bool = false,
        source: String = "",
        factID: UUID? = nil,
        voiceID: UUID? = nil,
        dateKey: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
        self.isOpen = isOpen
        self.source = source
        self.factID = factID
        self.voiceID = voiceID
        self.dateKey = dateKey
    }

    /// 从一个角色身上把四种条目摊成一个流，新的在前。
    ///
    /// 日子只取有概括的那些：空的那天在日历里能看，进记忆流只是噪音。
    static func collect(person: PersonMemory?, days: [CharacterDay]) -> [MemoryItem] {
        var items: [MemoryItem] = []

        if let person {
            let summary = person.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                items.append(
                    MemoryItem(
                        id: "summary",
                        kind: .summary,
                        text: summary,
                        createdAt: Date(timeIntervalSince1970: 0),
                        source: "聊得够多之后压出来的"
                    )
                )
            }

            items.append(contentsOf: person.facts.map { fact in
                MemoryItem(
                    id: "fact-\(fact.id.uuidString)",
                    kind: .fact,
                    text: fact.text,
                    createdAt: fact.createdAt,
                    source: fact.sourceName.isEmpty ? "对话里记下的" : "出自\(fact.sourceName)",
                    factID: fact.id
                )
            })

            items.append(contentsOf: person.voices.map { voice in
                MemoryItem(
                    id: "voice-\(voice.id.uuidString)",
                    kind: .voice,
                    text: voice.text,
                    createdAt: voice.createdAt,
                    isOpen: !voice.isResolved,
                    source: voice.isResolved ? "已经放下了" : "还没说出口",
                    voiceID: voice.id
                )
            })
        }

        // 空概括的日子不进流：日程是本地排的，每天都有一条，
        // 没聊过的那天标题是空的，滚下来全是空白条目。
        items.append(contentsOf: days.compactMap { day -> MemoryItem? in
            let text = day.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return MemoryItem(
                id: "day-\(day.dateKey)",
                kind: .day,
                text: text,
                createdAt: day.generatedAt,
                source: "\(TimeFormat.dayLabel(day.dateKey)) · \(day.mood.label)",
                dateKey: day.dateKey
            )
        })

        // 概括不参与按时间排：它没有具体时间，按 1970 排会永远沉到底，
        // 而它其实是「最旧也最重」的那一条，单独钉在顶部。
        return items.sorted { lhs, rhs in
            if lhs.kind == .summary { return true }
            if rhs.kind == .summary { return false }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
