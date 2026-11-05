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
struct ReplyEnvelope {
    struct Meta: Codable {
        var mood: String?
        var moodReason: String?
        var voice: String?
        var memory: String?
        var scheduleNote: String?
        var moment: String?
        var voiceResolvedID: String?
    }

    static let openTag = "<<<meta>>>"
    static let closeTag = "<<<end>>>"

    let visibleText: String
    let meta: Meta?

    /// 流式过程中也要把标签之后的内容藏起来，否则用户会看到原始 JSON。
    static func streamingVisible(_ raw: String) -> String {
        guard let range = raw.range(of: openTag) else { return raw }
        return String(raw[..<range.lowerBound])
    }

    static func parse(_ raw: String) -> ReplyEnvelope {
        guard let openRange = raw.range(of: openTag) else {
            return ReplyEnvelope(visibleText: raw, meta: nil)
        }

        let visible = String(raw[..<openRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(raw[openRange.upperBound...])
        let json: String
        if let closeRange = tail.range(of: closeTag) {
            json = String(tail[..<closeRange.lowerBound])
        } else {
            json = tail
        }

        guard let data = json.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else {
            // 降级：块坏了就把整段原文当正文，保证对话不丢内容。
            return ReplyEnvelope(visibleText: raw, meta: nil)
        }

        return ReplyEnvelope(visibleText: visible, meta: meta)
    }
}
