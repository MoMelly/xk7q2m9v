import Foundation
import SwiftData

/// 全量导出与恢复。
///
/// 自签 App 的数据随时可能因为重签而消失，所以「能导出」不是备份功能，
/// 是基本盘。格式用明文 JSON：换手机、改代码、甚至拿去喂给别的工具都能用。
enum DataBackup {
    static let currentVersion = 2

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "这份备份是更新的版本（v\(version)）导出的，当前 App 读不了。先把 App 升级再恢复。"
            }
        }
    }

    struct Payload: Codable {
        struct Msg: Codable {
            var role: String
            var text: String
            var speaker: String?
            var isNarration: Bool
            var createdAt: Date
        }

        struct Char: Codable {
            var uid: UUID
            var name: String
            var avatarTintRaw: String
            var persona: String
            var greeting: String
            var presetRaw: String
            var replyLengthRaw: String
            var isGroup: Bool
            var membersNote: String
            var wakeHour: Int
            var sleepHour: Int
            var createdAt: Date
            var sortIndex: Int
            var lastMessageAt: Date?
            var memorySummary: String
            var memoryCursor: Date?
            var totalReplies: Int
            var messages: [Msg]
            /// v2 新增。老备份里没有这些字段，所以全部可选。
            var signature: String?
            var tagsRaw: String?
            var canReadCalendar: Bool?
            var isNPC: Bool?
        }

        /// 我自己的备忘录。角色记忆在世界状态里，不走这里。
        struct Note: Codable {
            var title: String
            var body: String
            var folder: String
            var isPinned: Bool
            var createdAt: Date
            var updatedAt: Date
        }

        struct Moment: Codable {
            var characterUID: UUID
            var characterName: String
            var text: String
            var createdAt: Date
            var tintSeed: Int
        }

        struct World: Codable {
            var characterUID: UUID?
            var keywords: String
            var content: String
            var enabled: Bool
            var createdAt: Date
        }

        var version: Int
        var exportedAt: Date
        var characters: [Char]
        var moments: [Moment]
        var world: [World]
        /// v2 新增。可选，否则 v1 的备份会整份解不开。
        var notes: [Note]?
    }

    // MARK: - 导出

    /// 生成备份文件，返回临时文件地址供系统分享面板使用。
    static func export(context: ModelContext) throws -> URL {
        let characters = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
        let moments = (try? context.fetch(FetchDescriptor<MomentPost>())) ?? []
        let world = (try? context.fetch(FetchDescriptor<WorldEntry>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<NoteItem>())) ?? []

        let payload = Payload(
            version: currentVersion,
            exportedAt: Date(),
            characters: characters
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { character in
                    Payload.Char(
                        uid: character.uid,
                        name: character.name,
                        avatarTintRaw: character.avatarTintRaw,
                        persona: character.persona,
                        greeting: character.greeting,
                        presetRaw: character.presetRaw,
                        replyLengthRaw: character.replyLengthRaw,
                        isGroup: character.isGroup,
                        membersNote: character.membersNote,
                        wakeHour: character.wakeHour,
                        sleepHour: character.sleepHour,
                        createdAt: character.createdAt,
                        sortIndex: character.sortIndex,
                        lastMessageAt: character.lastMessageAt,
                        memorySummary: character.memorySummary,
                        memoryCursor: character.memoryCursor,
                        totalReplies: character.totalReplies,
                        messages: character.messages
                            .sorted { $0.createdAt < $1.createdAt }
                            .map {
                                Payload.Msg(
                                    role: $0.roleRaw,
                                    text: $0.text,
                                    speaker: $0.speaker,
                                    isNarration: $0.isNarration,
                                    createdAt: $0.createdAt
                                )
                            },
                        signature: character.signature,
                        tagsRaw: character.tagsRaw,
                        canReadCalendar: character.canReadCalendar,
                        isNPC: character.isNPC
                    )
                },
            moments: moments
                .sorted { $0.createdAt < $1.createdAt }
                .map {
                    Payload.Moment(
                        characterUID: $0.characterUID,
                        characterName: $0.characterName,
                        text: $0.text,
                        createdAt: $0.createdAt,
                        tintSeed: $0.tintSeed
                    )
                },
            world: world.map {
                Payload.World(
                    characterUID: $0.characterUID,
                    keywords: $0.keywords,
                    content: $0.content,
                    enabled: $0.enabled,
                    createdAt: $0.createdAt
                )
            },
            notes: notes
                .sorted { $0.updatedAt < $1.updatedAt }
                .map {
                    Payload.Note(
                        title: $0.title,
                        body: $0.body,
                        folder: $0.folder,
                        isPinned: $0.isPinned,
                        createdAt: $0.createdAt,
                        updatedAt: $0.updatedAt
                    )
                }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("miniphone-backup-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent("data.json"), options: .atomic)

        // 视频壁纸和世界状态是 Documents 下的独立文件，直接拷进备份目录。
        // 不做 base64 内嵌：一个几十 MB 的视频会让 JSON 体积和解码内存同时翻几倍。
        if VideoWallpaperStore.exists {
            let video = try Data(contentsOf: VideoWallpaperStore.fileURL)
            try video.write(
                to: folder.appendingPathComponent(VideoWallpaperStore.fileName),
                options: .atomic
            )
        }
        if let world = try? Data(contentsOf: WorldStateFile.url) {
            try world.write(
                to: folder.appendingPathComponent("world-state.json"),
                options: .atomic
            )
        }
        return folder
    }

    // MARK: - 恢复

    /// 恢复会先清空再写入。调用方必须让用户确认过。
    static func restore(from url: URL, context: ModelContext) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        let isFolder = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        // 兼容两种选法：直接选备份文件夹，或选旧版那种单独的 json。
        let jsonURL = isFolder ? url.appendingPathComponent("data.json") : url
        let folder = isFolder ? url : url.deletingLastPathComponent()

        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: data)

        // 备份文件的格式版本高于当前代码能读的，直接拒绝，
        // 免得「恢复成功」之后字段静默丢失。
        guard payload.version <= currentVersion else {
            throw BackupError.unsupportedVersion(payload.version)
        }

        // 清空
        for item in (try? context.fetch(FetchDescriptor<StoredMessage>())) ?? [] {
            context.delete(item)
        }
        for item in (try? context.fetch(FetchDescriptor<Companion>())) ?? [] {
            context.delete(item)
        }
        for item in (try? context.fetch(FetchDescriptor<MomentPost>())) ?? [] {
            context.delete(item)
        }
        for item in (try? context.fetch(FetchDescriptor<WorldEntry>())) ?? [] {
            context.delete(item)
        }
        for item in (try? context.fetch(FetchDescriptor<NoteItem>())) ?? [] {
            context.delete(item)
        }

        var messageCount = 0

        for item in payload.characters {
            let character = Companion(
                name: item.name,
                persona: item.persona,
                greeting: item.greeting,
                preset: RoleplayPreset(rawValue: item.presetRaw) ?? .daily,
                avatarTintRaw: item.avatarTintRaw,
                replyLength: ReplyLength(rawValue: item.replyLengthRaw) ?? .medium,
                isGroup: item.isGroup,
                membersNote: item.membersNote,
                wakeHour: item.wakeHour,
                sleepHour: item.sleepHour,
                sortIndex: item.sortIndex
            )
            // 保留原来的 uid：动态和设定集条目里存的是这个 uid，
            // 重新生成一个的话它们就都指向了一个不存在的角色，
            // 表现成「恢复之后世界书全部失效、动态头像颜色全变默认色」。
            character.uid = item.uid
            character.createdAt = item.createdAt
            character.lastMessageAt = item.lastMessageAt
            character.memorySummary = item.memorySummary
            character.memoryCursor = item.memoryCursor
            character.totalReplies = item.totalReplies
            character.signature = item.signature ?? ""
            character.tagsRaw = item.tagsRaw ?? ""
            character.canReadCalendar = item.canReadCalendar ?? false
            character.isNPC = item.isNPC ?? false
            context.insert(character)

            for message in item.messages {
                let stored = StoredMessage(
                    characterUID: character.uid,
                    role: ChatMessage.Role(rawValue: message.role) ?? .assistant,
                    text: message.text,
                    speaker: message.speaker,
                    isNarration: message.isNarration,
                    createdAt: message.createdAt
                )
                stored.character = character
                context.insert(stored)
                messageCount += 1
            }
        }

        for item in payload.moments {
            let post = MomentPost(
                characterUID: item.characterUID,
                characterName: item.characterName,
                text: item.text
            )
            post.createdAt = item.createdAt
            post.tintSeed = item.tintSeed
            context.insert(post)
        }

        for item in payload.world {
            let entry = WorldEntry(
                characterUID: item.characterUID,
                keywords: item.keywords,
                content: item.content
            )
            entry.enabled = item.enabled
            entry.createdAt = item.createdAt
            context.insert(entry)
        }

        for item in payload.notes ?? [] {
            let note = NoteItem(title: item.title, body: item.body, folder: item.folder)
            note.isPinned = item.isPinned
            note.createdAt = item.createdAt
            note.updatedAt = item.updatedAt
            context.insert(note)
        }

        try context.save()

        var extras: [String] = []
        let videoSource = folder.appendingPathComponent(VideoWallpaperStore.fileName)
        if let video = try? Data(contentsOf: videoSource) {
            try? VideoWallpaperStore.replace(with: video)
            extras.append("视频壁纸")
        }
        let worldSource = folder.appendingPathComponent("world-state.json")
        if let snapshot = try? Data(contentsOf: worldSource) {
            try? snapshot.write(to: WorldStateFile.url, options: .atomic)
            extras.append("世界状态")
        }

        let suffix = extras.isEmpty ? "" : "，以及" + extras.joined(separator: "、")
        return "恢复了 \(payload.characters.count) 个角色、\(messageCount) 条消息、\(payload.notes?.count ?? 0) 条备忘录\(suffix)。"
    }
}
