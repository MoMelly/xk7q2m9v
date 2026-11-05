import Foundation

/// 计费模式在配置接口时选定，不同的模型各自存一份。
enum BillingMode: String, Codable, CaseIterable, Identifiable {
    case perCall
    case perToken

    var id: String { rawValue }

    var label: String {
        switch self {
        case .perCall: return "按次计费"
        case .perToken: return "按量计费"
        }
    }

    var detail: String {
        switch self {
        case .perCall: return "后台任务并进同一轮回复，压缩记忆不再单独调用"
        case .perToken: return "压短上下文，压缩记忆按阈值单独调用"
        }
    }
}

/// 一轮生成的策略参数。
struct GenerationPlan {
    let mode: BillingMode

    /// 按次时把副产物合进正文后的元数据块，所以不再单独发起压缩调用。
    var mergesSideEffects: Bool { mode == .perCall }

    /// 按量时把上下文压短，按次时把阈值抬高到几乎不触发独立压缩。
    var contextWindow: Int { mode == .perCall ? 28 : 40 }
    var compressionThreshold: Int { mode == .perCall ? 10_000 : 40 }
    var keepRecent: Int { 20 }
}

/// 回复正文后的机器可解析块。
///
/// 模型偶尔会写坏这个块：解析失败时整段原文当正文返回，
/// 不影响聊天，只是这一次没拿到状态增量。
/// 数组里单个元素坏掉时只丢那一个。
///
/// 模型写 `shop` 常常一条好一条坏，整块 `try?` 会让另外几条也一起消失。
struct Lenient<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

struct ReplyEnvelope {
    /// 一条被推出来的商品。
    ///
    /// 字段全部可选是给模型留的余地：它经常只写得出标题和价格，
    /// 少一个字段不该让整条作废。价格按「元」收，字符串和数字都认——
    /// 有的模型会把 `39.9` 写成 `"¥39.9"`。
    struct ShopDraft: Decodable {
        var title: String?
        var price: Double?
        var note: String?
        var reason: String?
        var category: String?

        private enum CodingKeys: String, CodingKey {
            case title, price, note, reason, category
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            note = try? container.decodeIfPresent(String.self, forKey: .note)
            reason = try? container.decodeIfPresent(String.self, forKey: .reason)
            category = try? container.decodeIfPresent(String.self, forKey: .category)

            if let number = try? container.decodeIfPresent(Double.self, forKey: .price) {
                price = number
            } else if let text = try? container.decodeIfPresent(String.self, forKey: .price) {
                let digits = text.filter { $0.isNumber || $0 == "." }
                price = Double(digits)
            }
        }
    }

    /// 一条要发出去的笔记。
    struct FeedDraft: Decodable {
        var title: String?
        var body: String?
        var tag: String?
        var author: String?
        /// 底下已经有人说的话。给一两条就够，多了模型写不动。
        var comments: [String]?

        private enum CodingKeys: String, CodingKey {
            case title, body, tag, author, comments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            body = try? container.decodeIfPresent(String.self, forKey: .body)
            tag = try? container.decodeIfPresent(String.self, forKey: .tag)
            author = try? container.decodeIfPresent(String.self, forKey: .author)
            comments = try? container.decodeIfPresent([String].self, forKey: .comments)
        }
    }

    /// 补到已有笔记下面的一条评论。
    ///
    /// 模型写不出上一轮笔记的 UUID，所以这里用标题定位。
    struct FeedComment: Decodable {
        var title: String?
        var author: String?
        var text: String?

        private enum CodingKeys: String, CodingKey {
            case title, author, text
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            author = try? container.decodeIfPresent(String.self, forKey: .author)
            text = try? container.decodeIfPresent(String.self, forKey: .text)
        }
    }

    /// 回复尾部的状态块。
    ///
    /// 逐字段 `decodeIfPresent`：合成为 `Codable` 时只要有一个 key 类型不对，
    /// 整块就解不出来，而这一块的兜底是把原文当正文——用户会直接看见裸 JSON。
    struct Meta: Decodable {
        var mood: String?
        var moodReason: String?
        var voice: String?
        var memory: String?
        var scheduleNote: String?
        var moment: String?
        var voiceResolvedID: String?
        /// 刷新引擎要的增量。只有判定过要刷新的那一轮才该有值。
        var shop: [ShopDraft]?
        var feed: [FeedDraft]?
        /// 补到旧笔记下面的评论。
        var feedComments: [FeedComment]?

        private enum CodingKeys: String, CodingKey {
            case mood, moodReason, voice, memory, scheduleNote, moment
            case voiceResolvedID, shop, feed, feedComments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mood = try? container.decodeIfPresent(String.self, forKey: .mood)
            moodReason = try? container.decodeIfPresent(String.self, forKey: .moodReason)
            voice = try? container.decodeIfPresent(String.self, forKey: .voice)
            memory = try? container.decodeIfPresent(String.self, forKey: .memory)
            scheduleNote = try? container.decodeIfPresent(String.self, forKey: .scheduleNote)
            moment = try? container.decodeIfPresent(String.self, forKey: .moment)
            voiceResolvedID = try? container.decodeIfPresent(String.self, forKey: .voiceResolvedID)

            let shopItems = (try? container.decodeIfPresent([Lenient<ShopDraft>].self, forKey: .shop)) ?? nil
            shop = shopItems?.compactMap(\.value)
            let feedItems = (try? container.decodeIfPresent([Lenient<FeedDraft>].self, forKey: .feed)) ?? nil
            feed = feedItems?.compactMap(\.value)
            let commentItems = (try? container.decodeIfPresent([Lenient<FeedComment>].self, forKey: .feedComments)) ?? nil
            feedComments = commentItems?.compactMap(\.value)
        }
    }

    static let openTag = "<<<meta>>>"
    static let closeTag = "<<<end>>>"

    /// 模型不总会照着写。这几种变体在实测里都出现过，认下来比丢掉整块好。
    private static let openVariants = [
        "<<<meta>>>", "<<<META>>>", "<<<Meta>>>", "<<<meta>>", "<meta>", "[meta]"
    ]
    private static let closeVariants = [
        "<<<end>>>", "<<<END>>>", "<<<end>>", "</meta>", "[/meta]"
    ]

    let visibleText: String
    let meta: Meta?
    /// 状态块原文，没解析过的样子。设置里的「原始回复」要展示它。
    let rawMeta: String?

    /// 流式过程中也要把标签之后的内容藏起来，否则用户会看着 JSON 一个字一个字冒出来。
    ///
    /// 标签本身还没写全的时候（比如刚输出到 `<<<met`），把这段半截标签也削掉，
    /// 不然收尾那一瞬间会闪一下尖括号。
    static func streamingVisible(_ raw: String) -> String {
        let trimmed = cutAtOpenTag(raw).text
        return cutPartialTag(trimmed)
    }

    static func parse(_ raw: String) -> ReplyEnvelope {
        // 先看有没有标签。没有标签时再退一步：正文末尾跟了一段裸 JSON，也认。
        let head = cutAtOpenTag(raw)
        let visible: String
        let json: String?

        if let body = head.json {
            visible = head.text.trimmingCharacters(in: .whitespacesAndNewlines)
            json = body
        } else if let trailing = trailingJSON(raw) {
            visible = trailing.text.trimmingCharacters(in: .whitespacesAndNewlines)
            json = trailing.json
        } else {
            return ReplyEnvelope(
                visibleText: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                meta: nil,
                rawMeta: nil
            )
        }

        guard let json,
              let data = cleanJSON(json).data(using: .utf8),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else {
            // 块坏掉时只丢状态增量，正文照常上屏。
            // 之前的兜底是把整段原文当正文，用户会看到裸露的 JSON。
            return ReplyEnvelope(visibleText: visible, meta: nil, rawMeta: json)
        }

        return ReplyEnvelope(visibleText: visible, meta: meta, rawMeta: json)
    }

    /// 找开标签。块写在正文前面时，正文要取闭标签之后的半段。
    private static func cutAtOpenTag(_ raw: String) -> (text: String, json: String?) {
        var best: Range<String.Index>?
        for variant in openVariants {
            if let range = raw.range(of: variant),
               best.map({ range.lowerBound < $0.lowerBound }) ?? true {
                best = range
            }
        }

        guard let range = best else { return (raw, nil) }

        let before = String(raw[..<range.lowerBound])
        let tail = String(raw[range.upperBound...])

        if before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let close = firstRange(of: closeVariants, in: tail) {
            // 整段只有状态块，正文在闭标签后面。两段都要带出去，
            // 否则下面的「裸 JSON」兜底会把开头那段 JSON 当成正文切错。
            let body = String(tail[..<close.lowerBound])
            let rest = String(tail[close.upperBound...])
            return (rest, body.isEmpty ? nil : body)
        }

        let body: String
        if let close = firstRange(of: closeVariants, in: tail) {
            body = String(tail[..<close.lowerBound])
        } else {
            body = tail
        }
        return (before, body)
    }

    /// 没有标签、但正文末尾跟了一个 JSON 对象的情况。
    ///
    /// 只在「最后一个 `{` 之后能配平成对象、且带引号键」时才切，
    /// 免得把正文里正常出现的花括号当成分隔符。
    private static func trailingJSON(_ raw: String) -> (text: String, json: String)? {
        guard let lastOpen = raw.lastIndex(of: "{") else { return nil }
        let candidate = String(raw[lastOpen...])
        guard candidate.hasSuffix("}"), candidate.contains("\":") else { return nil }
        return (String(raw[..<lastOpen]), candidate)
    }

    private static func firstRange(of variants: [String], in text: String) -> Range<String.Index>? {
        var best: Range<String.Index>?
        for variant in variants {
            if let range = text.range(of: variant),
               best.map({ range.lowerBound < $0.lowerBound }) ?? true {
                best = range
            }
        }
        return best
    }

    /// 去掉围栏和行首空白。模型很爱在 JSON 外面套 ```json。
    private static func cleanJSON(_ raw: String) -> String {
        var text = raw
        for token in ["```json", "```JSON", "```"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 流式阶段削掉末尾的半截标签。
    private static func cutPartialTag(_ text: String) -> String {
        for token in openVariants {
            let limit = min(token.count - 1, text.count)
            guard limit >= 3 else { continue }
            for length in stride(from: limit, through: 3, by: -1) {
                if text.hasSuffix(String(token.prefix(length))) {
                    return String(text.dropLast(length))
                }
            }
        }
        return text
    }
}
