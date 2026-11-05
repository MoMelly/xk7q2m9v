import Foundation
import Observation

/// 一次模型回复的原始记录。
///
/// 存的是**没被处理过**的原文：正文、状态块、多余的换行、写歪的标签，
/// 全都照原样留着。解析失败的那些尤其要看——只有看原文才知道是模型写坏了
/// 还是解析写窄了。
struct RawReplyRecord: Codable, Identifiable {
    var id: UUID
    var at: Date
    var characterName: String
    var model: String
    /// 模型吐出来的全部内容。
    var raw: String
    /// 解析后真正上屏的正文。
    var visible: String
    /// 状态块原文；没有块时为 nil。
    var metaText: String?
    /// 状态块是否解析成功。
    var parsedOK: Bool

    var hasMeta: Bool { metaText != nil }

    /// 列表上的一行摘要：第一句非空正文。
    var preview: String {
        let firstLine = visible
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        return firstLine.isEmpty ? "（正文为空）" : firstLine
    }
}

/// 原始回复日志。
///
/// 单独落一个 JSON 文件，不写进 SwiftData：这是一份只增不改的调试记录，
/// 和业务数据没有关系，混进主库只会让迁移更麻烦。
@Observable
@MainActor
final class RawReplyLog {
    static let shared = RawReplyLog()

    /// 留最近这么多条。一条一两千字，两百条也就几百 KB。
    private static let limit = 200

    private(set) var records: [RawReplyRecord] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("raw-replies.json")
        self.fileURL = url
        load()
    }

    func append(
        characterName: String,
        model: String,
        raw: String,
        envelope: ReplyEnvelope
    ) {
        let record = RawReplyRecord(
            id: UUID(),
            at: Date(),
            characterName: characterName,
            model: model,
            raw: raw,
            visible: envelope.visibleText,
            metaText: envelope.rawMeta,
            parsedOK: envelope.meta != nil
        )

        records.insert(record, at: 0)
        if records.count > Self.limit {
            records.removeLast(records.count - Self.limit)
        }
        save()
    }

    func clear() {
        records = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([RawReplyRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
