import Foundation

/// 酒馆角色卡导入。
///
/// 兼容两种格式：
/// - **PNG 卡**：图片里塞了一个 `tEXt` 块，关键字是 `chara`（V2）或 `ccv3`，
///   内容是 base64 编码的 JSON。这是酒馆最常见的分发形式。
/// - **JSON 卡**：V2 是 `{ "data": { ... } }`，V1 是平铺字段。
///
/// 只取文本相关字段，图片本身不用——头像走渐变圆，省包体也避免版权问题。
enum CharacterCardImporter {
    struct ImportedCard {
        var name: String
        var persona: String
        var greeting: String
        /// 原始 JSON 里能认出来的字段数，用来判断「是不是真导入成功了」。
        var filledFields: Int
    }

    enum ImportError: LocalizedError {
        case unreadable
        case noCardData
        case badBase64
        case emptyCard

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "这个文件读不出来。"
            case .noCardData:
                return "文件里没找到角色卡数据。PNG 卡需要带 chara 信息，普通截图不行。"
            case .badBase64:
                return "卡片里的数据编码坏了，可能文件被改过。"
            case .emptyCard:
                return "卡片里没有名字也没有人设，导进来也没用。"
            }
        }
    }

    static func load(from url: URL) throws -> ImportedCard {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return try parsePNG(data)
        }
        return try parseJSON(data)
    }

    // MARK: - JSON

    static func parseJSON(_ data: Data) throws -> ImportedCard {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.unreadable
        }

        // V2 把字段放在 data 里，V1 平铺。
        let fields: [String: Any]
        if let nested = root["data"] as? [String: Any] {
            fields = nested
        } else {
            fields = root
        }

        return try build(from: fields)
    }

    // MARK: - PNG

    static func parsePNG(_ data: Data) throws -> ImportedCard {
        guard let text = extractTextChunk(from: data) else { throw ImportError.noCardData }

        // 有些卡直接存明文 JSON，有些存 base64，两种都试。
        if let direct = text.data(using: .utf8),
           let card = try? parseJSON(direct),
           !card.name.isEmpty {
            return card
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decoded = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters) else {
            throw ImportError.badBase64
        }
        return try parseJSON(decoded)
    }

    /// 遍历 PNG 的块，找关键字为 chara / ccv3 的文本块。
    ///
    /// `tEXt` 和 `iTXt` 的载荷结构不一样：iTXt 在关键字后面还有压缩标志、
    /// 语言标签、翻译关键字三样东西，直接从第一个 `\0` 后面取文本会拿到二进制垃圾。
    private static func extractTextChunk(from data: Data) -> String? {
        let signatureLength = 8
        guard data.count > signatureLength + 8 else { return nil }

        var offset = signatureLength
        let bytes = [UInt8](data)

        while offset + 8 <= bytes.count {
            let length = Int(beUInt32(bytes, offset))
            let typeStart = offset + 4
            guard typeStart + 4 <= bytes.count else { return nil }

            let type = String(bytes: bytes[typeStart..<(typeStart + 4)], encoding: .ascii) ?? ""
            let dataStart = typeStart + 4
            let dataEnd = dataStart + length
            // 块结构：长度(4) + 类型(4) + 数据 + CRC(4)
            guard dataEnd >= dataStart, dataEnd + 4 <= bytes.count else { return nil }

            let payload = bytes[dataStart..<dataEnd]

            switch type {
            case "tEXt":
                if let text = plainTextPayload(payload) { return text }
            case "iTXt":
                if let text = internationalTextPayload(payload) { return text }
            case "IEND":
                return nil
            default:
                break
            }

            offset = dataEnd + 4
        }

        return nil
    }

    /// `tEXt`：关键字 `\0` 文本
    private static func plainTextPayload(_ payload: ArraySlice<UInt8>) -> String? {
        guard let separator = payload.firstIndex(of: 0) else { return nil }
        let keyword = String(bytes: payload[payload.startIndex..<separator], encoding: .ascii) ?? ""
        guard keyword == "chara" || keyword == "ccv3" else { return nil }

        let body = payload[(separator + 1)...]
        guard let text = String(bytes: body, encoding: .utf8), !text.isEmpty else { return nil }
        return text
    }

    /// `iTXt`：关键字 `\0` 压缩标志(1) 压缩方法(1) 语言 `\0` 翻译关键字 `\0` 文本
    private static func internationalTextPayload(_ payload: ArraySlice<UInt8>) -> String? {
        guard let keywordEnd = payload.firstIndex(of: 0) else { return nil }
        let keyword = String(bytes: payload[payload.startIndex..<keywordEnd], encoding: .ascii) ?? ""
        guard keyword == "chara" || keyword == "ccv3" else { return nil }

        var cursor = payload.index(after: keywordEnd)
        guard cursor + 1 < payload.endIndex else { return nil }
        let compressionFlag = payload[cursor]
        cursor += 2

        guard let languageEnd = payload[cursor...].firstIndex(of: 0) else { return nil }
        cursor = payload.index(after: languageEnd)
        guard let translatedEnd = payload[cursor...].firstIndex(of: 0) else { return nil }
        cursor = payload.index(after: translatedEnd)

        // 压缩过的块要用 zlib 解，项目里没带这个依赖；跳过，交给后面的 base64 分支。
        guard compressionFlag == 0 else { return nil }

        guard let text = String(bytes: payload[cursor...], encoding: .utf8), !text.isEmpty else { return nil }
        return text
    }

    private static func beUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    // MARK: - 字段拼装

    private static func build(from fields: [String: Any]) throws -> ImportedCard {
        func string(_ keys: [String]) -> String {
            for key in keys {
                if let value = fields[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
            return ""
        }

        let name = string(["name", "char_name"])
        let description = string(["description", "char_persona", "persona"])
        let personality = string(["personality"])
        let scenario = string(["scenario", "world_scenario"])
        let example = string(["mes_example", "example_dialogue"])
        let greeting = string(["first_mes", "char_greeting", "greeting"])

        var blocks: [String] = []
        if !description.isEmpty { blocks.append(description) }
        if !personality.isEmpty && personality != description {
            blocks.append("性格：" + personality)
        }
        if !scenario.isEmpty { blocks.append("背景：" + scenario) }
        if !example.isEmpty {
            // 示例对话里有 {{user}} / {{char}} 宏，换成「用户」「你」，
            // 否则模型会照着宏原样输出。
            let cleaned = example
                .replacingOccurrences(of: "{{char}}", with: name.isEmpty ? "你" : name)
                .replacingOccurrences(of: "{{user}}", with: "用户")
                .replacingOccurrences(of: "<START>", with: "")
            blocks.append("对话示例（参考语气，不要照抄）：\n" + cleaned)
        }

        let persona = blocks.joined(separator: "\n\n")

        guard !name.isEmpty || !persona.isEmpty else { throw ImportError.emptyCard }

        let filled = [name, description, personality, scenario, example, greeting]
            .filter { !$0.isEmpty }
            .count

        return ImportedCard(
            name: name,
            persona: persona,
            greeting: greeting,
            filledFields: filled
        )
    }
}
