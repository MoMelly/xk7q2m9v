import Foundation
import SwiftData

/// 全量导出与恢复。
///
/// 自签 App 的数据随时可能因为重签而消失，所以「能导出」不是备份功能，
/// 是基本盘。格式用明文 JSON：换手机、改代码、甚至拿去喂给别的工具都能用。
enum DataBackup {
    /// v3：消息补 imageSeed（模拟图），角色补上传头像，新增「我的」身份列表，
    /// 备份目录里带上用户上传的头像照片文件。重装前导出才真正是一份全量。
    ///
    /// v11：表情库和书架进备份。版本号之前一直停在 3，字段却已经追加到 v10，
    /// 于是「版本号」不再能说明任何事——一份 v3 的旧备份和一份带世界书条件、
    /// 带红包的备份长得一样。这里按字段的轮次重新对齐，之后每加字段就跟着加。
    static let currentVersion = 11

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
            /// v3 新增。模拟图片的画图种子，0 或缺省 = 纯文字。
            var imageSeed: Int?
            /// v4 新增。撤回 / 引用 / 编辑这三件事要跟着备份走，
            /// 否则恢复之后撤回的消息又冒出来，引用块也丢了。
            var isRecalled: Bool?
            /// 置顶是界面状态，不属于聊天内容，但备份丢掉它
            /// 用户会以为「恢复以后置顶怎么就没了」。
            var isPinned: Bool?
            var quoteSpeaker: String?
            var quoteText: String?
            var editedAt: Date?
            /// v5 新增。红包：金额（分）、封面上那句话、拆没拆。
            var packetCents: Int?
            var packetNote: String?
            var packetOpened: Bool?
            /// v4 新增。通道与线程决定这条消息显示在哪：主聊天、西瓜皮私信、
            /// 还是转帖。漏了的话恢复之后私信和转帖全部塌回主聊天，
            /// 拍一拍也会变成一条普通消息。
            var channelRaw: String?
            var threadRaw: String?
            var isPat: Bool?
            /// 这条消息属于哪个身份。老备份没有，恢复时按默认身份。
            var personaUID: String?
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
            /// 每个身份各自那份摘要（JSON）。老备份没有就是空。
            var memoryByPersonaRaw: String?
            var memoryCursor: Date?
            var totalReplies: Int
            var messages: [Msg]
            /// v2 新增。老备份里没有这些字段，所以全部可选。
            var signature: String?
            var tagsRaw: String?
            var canReadCalendar: Bool?
            var isNPC: Bool?
            /// v3 新增。内置头像键与上传头像文件名。
            var avatarImageKey: String?
            var avatarFileName: String?
            /// v4 新增。这几个字段在 `Companion` 上早就有了，备份一直没带。
            /// 漏着的后果是恢复之后：所有会话的「我以谁的身份」回落成默认身份、
            /// 西瓜皮路人作者全变成正式角色涌进信息列表、拍一拍后缀没了、
            /// 屏蔽过的贴纸又全部冒出来。
            var personaUID: String?
            var isFeedOnly: Bool?
            var patSuffix: String?
            var blockedStickerGroupsRaw: String?
            var blockedStickerNamesRaw: String?
            /// v6 新增。这个角色自己的朗读音色与语速。
            /// 漏了的话恢复之后所有人的嗓子都回到「按名字自动挑」，
            /// 用户一个个调过的音色全白设。
            var voiceID: String?
            var voiceRate: Double?
        }

        /// 「我的」里的一个身份。v3 新增，老备份没有整段。
        struct User: Codable {
            var uid: UUID
            var name: String
            var signature: String
            var bio: String
            var tagsRaw: String
            var statusText: String
            var statusStickerName: String
            var avatarTintRaw: String
            var avatarSymbol: String
            var avatarImageKey: String
            var avatarFileName: String
            var isDefault: Bool
            var createdAt: Date
            /// 别人拍我时名字后面的后缀。和 `Companion.patSuffix` 是同一类字段，
            /// 那边备份了、这边漏了；缺键时按空串恢复。
            var patSuffix: String?
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
            /// v9 新增：常驻条目。旧备份没有这个键，读出来当关键词条目。
            var alwaysOn: Bool?
            /// v10 新增：分类、优先级、插入位置、条件四个维度。
            /// 全部可选——v9 及更早的备份里没有这些键，缺了就按老规矩反推。
            var kind: String?
            var priority: Int?
            var position: String?
            var condPhases: String?
            var condMoods: String?
            var condLocation: String?
            var condMinDays: Int?
        }

        var version: Int
        var exportedAt: Date
        var characters: [Char]
        var moments: [Moment]
        var world: [World]
        /// v2 新增。可选，否则 v1 的备份会整份解不开。
        var notes: [Note]?
        /// v3 新增。「我的」里的全部身份。
        var users: [User]?
        /// v11 新增。表情库。图片文件本来就在 `stickers/` 里跟着备份走，
        /// 但库里这些记录一直没备，恢复完变成「文件在、列表空」。
        var stickers: [Sticker]?
        /// v11 新增。我导入的 txt 和读到的位置。正文只在库里，丢了就真没了。
        var books: [Book]?
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
                        memoryByPersonaRaw: character.memoryByPersonaRaw.isEmpty
                            ? nil : character.memoryByPersonaRaw,
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
                                    createdAt: $0.createdAt,
                                    imageSeed: $0.imageSeed == 0 ? nil : $0.imageSeed,
                                    isRecalled: $0.isRecalled ? true : nil,
                                    isPinned: $0.isPinned ? true : nil,
                                    quoteSpeaker: $0.quoteSpeaker.isEmpty ? nil : $0.quoteSpeaker,
                                    quoteText: $0.quoteText.isEmpty ? nil : $0.quoteText,
                                    editedAt: $0.editedAt,
                                    packetCents: $0.packetCents == 0 ? nil : $0.packetCents,
                                    packetNote: $0.packetNote.isEmpty ? nil : $0.packetNote,
                                    packetOpened: $0.packetOpened ? true : nil,
                                    // 主聊天是默认值，存 nil 省体积；恢复时按 nil 还原成 chat。
                                    channelRaw: $0.channelRaw == MessageChannel.chat.rawValue
                                        ? nil : $0.channelRaw,
                                    threadRaw: $0.threadRaw.isEmpty ? nil : $0.threadRaw,
                                    isPat: $0.isPat ? true : nil,
                                    personaUID: $0.personaUID.isEmpty ? nil : $0.personaUID
                                )
                            },
                        signature: character.signature,
                        tagsRaw: character.tagsRaw,
                        canReadCalendar: character.canReadCalendar,
                        isNPC: character.isNPC,
                        avatarImageKey: character.avatarImageKey,
                        avatarFileName: character.avatarFileName,
                        personaUID: character.personaUID.isEmpty ? nil : character.personaUID,
                        isFeedOnly: character.isFeedOnly ? true : nil,
                        patSuffix: character.patSuffix.isEmpty ? nil : character.patSuffix,
                        blockedStickerGroupsRaw: character.blockedStickerGroupsRaw.isEmpty
                            ? nil : character.blockedStickerGroupsRaw,
                        blockedStickerNamesRaw: character.blockedStickerNamesRaw.isEmpty
                            ? nil : character.blockedStickerNamesRaw,
                        voiceID: character.voiceID.isEmpty ? nil : character.voiceID,
                        voiceRate: character.voiceRate > 0 ? character.voiceRate : nil
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
                    createdAt: $0.createdAt,
                    alwaysOn: $0.alwaysOn ? true : nil,
                    kind: $0.kindRaw.isEmpty ? nil : $0.kindRaw,
                    priority: $0.priority == 5 ? nil : $0.priority,
                    position: $0.positionRaw.isEmpty ? nil : $0.positionRaw,
                    condPhases: $0.condPhases.isEmpty ? nil : $0.condPhases,
                    condMoods: $0.condMoods.isEmpty ? nil : $0.condMoods,
                    condLocation: $0.condLocation.isEmpty ? nil : $0.condLocation,
                    condMinDays: $0.condMinDays == 0 ? nil : $0.condMinDays
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
                },
            users: exportUsers(context: context),
            // 表情和书走独立的读取函数：这两张表的映射一长串，
            // 塞进这个字面量会把导出那段撑到读不下去。
            stickers: exportStickers(context: context),
            books: exportBooks(context: context)
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
        try exportWorldState(to: folder)

        // 用户从相册传的头像是 Documents/avatars 下的 UUID 文件，
        // 内置头像（avatar_ 前缀）随包发布不用搬。逐个文件拷进备份目录。
        let avatarFiles = (try? FileManager.default.contentsOfDirectory(
            at: AvatarPhoto.directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in avatarFiles where file.lastPathComponent.hasSuffix(".jpg")
            && !file.lastPathComponent.hasPrefix("avatar_") {
            let destination = folder.appendingPathComponent("avatars", isDirectory: true)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            }
            try? FileManager.default.copyItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
        }

        // 文游存档、表情、壁纸、音乐、其它世界：都在 Documents 下的独立目录里。
        exportFileStores(to: folder)
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
            character.memoryByPersonaRaw = item.memoryByPersonaRaw ?? ""
            character.memoryCursor = item.memoryCursor
            character.totalReplies = item.totalReplies
            character.signature = item.signature ?? ""
            character.tagsRaw = item.tagsRaw ?? ""
            character.canReadCalendar = item.canReadCalendar ?? false
            character.isNPC = item.isNPC ?? false
            character.avatarImageKey = item.avatarImageKey ?? ""
            character.avatarFileName = item.avatarFileName ?? ""
            character.personaUID = item.personaUID ?? ""
            character.isFeedOnly = item.isFeedOnly ?? false
            character.patSuffix = item.patSuffix ?? ""
            character.blockedStickerGroupsRaw = item.blockedStickerGroupsRaw ?? ""
            character.blockedStickerNamesRaw = item.blockedStickerNamesRaw ?? ""
            character.voiceID = item.voiceID ?? ""
            character.voiceRate = item.voiceRate ?? 0
            context.insert(character)

            for message in item.messages {
                let stored = StoredMessage(
                    characterUID: character.uid,
                    role: ChatMessage.Role(rawValue: message.role) ?? .assistant,
                    text: message.text,
                    speaker: message.speaker,
                    isNarration: message.isNarration,
                    createdAt: message.createdAt,
                    personaUID: message.personaUID ?? ""
                )
                stored.imageSeed = message.imageSeed ?? 0
                stored.isRecalled = message.isRecalled ?? false
                stored.isPinned = message.isPinned ?? false
                stored.quoteSpeaker = message.quoteSpeaker ?? ""
                stored.quoteText = message.quoteText ?? ""
                stored.packetCents = message.packetCents ?? 0
                stored.packetNote = message.packetNote ?? ""
                stored.packetOpened = message.packetOpened ?? false
                stored.channelRaw = message.channelRaw ?? MessageChannel.chat.rawValue
                stored.threadRaw = message.threadRaw ?? ""
                stored.isPat = message.isPat ?? false
                stored.editedAt = message.editedAt
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
                content: item.content,
                kind: item.kind.flatMap(WorldTrigger.init(rawValue:))
                    ?? ((item.alwaysOn ?? false) ? .constant : .keyword),
                priority: item.priority ?? 5,
                position: item.position.flatMap(WorldPosition.init(rawValue:)) ?? .front
            )
            entry.enabled = item.enabled
            entry.createdAt = item.createdAt
            entry.condPhases = item.condPhases ?? ""
            entry.condMoods = item.condMoods ?? ""
            entry.condLocation = item.condLocation ?? ""
            entry.condMinDays = item.condMinDays ?? 0
            context.insert(entry)
        }

        for item in payload.notes ?? [] {
            let note = NoteItem(title: item.title, body: item.body, folder: item.folder)
            note.isPinned = item.isPinned
            note.createdAt = item.createdAt
            note.updatedAt = item.updatedAt
            context.insert(note)
        }

        // 身份是整段替换：v3 备份里存的是导出那一刻的全部身份。
        // 老备份没有这段就跳过，保留启动时建好的默认身份。
        if let users = payload.users {
            for item in (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [] {
                context.delete(item)
            }
            for item in users {
                let profile = UserProfile(
                    name: item.name,
                    signature: item.signature,
                    bio: item.bio,
                    tagsRaw: item.tagsRaw,
                    avatarTintRaw: item.avatarTintRaw,
                    isDefault: item.isDefault
                )
                profile.uid = item.uid
                profile.statusText = item.statusText
                profile.statusStickerName = item.statusStickerName
                profile.avatarSymbol = item.avatarSymbol
                profile.avatarImageKey = item.avatarImageKey
                profile.avatarFileName = item.avatarFileName
                profile.createdAt = item.createdAt
                profile.patSuffix = item.patSuffix ?? ""
                context.insert(profile)
            }
        }

        // 表情库和书架。旧备份里没有这两段，缺哪段就整段跳过——
        // 不能顺手清掉，否则「恢复一份老备份」会把现在手上的表情和书清空。
        if payload.stickers != nil || payload.books != nil {
            clearLibrary(
                context: context,
                stickers: payload.stickers != nil,
                books: payload.books != nil
            )
        }
        if let stickers = payload.stickers {
            restoreStickers(stickers, context: context)
        }
        if let books = payload.books {
            restoreBooks(books, context: context)
        }

        try context.save()

        var extras: [String] = []
        let videoSource = folder.appendingPathComponent(VideoWallpaperStore.fileName)
        if let video = try? Data(contentsOf: videoSource) {
            try? VideoWallpaperStore.replace(with: video)
            extras.append("视频壁纸")
        }
        if restoreWorldState(from: folder) { extras.append("世界状态") }

        // 上传的头像照片文件搬回 Documents/avatars，内置的随包不用动。
        let backupAvatars = folder.appendingPathComponent("avatars", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(
            at: backupAvatars,
            includingPropertiesForKeys: nil
        ), !files.isEmpty {
            for file in files {
                try? FileManager.default.copyItem(
                    at: file,
                    to: AvatarPhoto.directory.appendingPathComponent(file.lastPathComponent)
                )
            }
            extras.append("头像照片 \(files.count) 张")
        }
        if payload.users != nil {
            extras.append("我的身份")
        }

        // 文游存档、表情、壁纸、音乐、其它世界搬回来。
        extras.append(contentsOf: restoreFileStores(from: folder))

        // 动态和世界书也真的写库了。清单里不写的话，用户看不出这两块回来没有。
        var parts = [
            "\(payload.characters.count) 个角色",
            "\(messageCount) 条消息",
            "\(payload.notes?.count ?? 0) 条备忘录"
        ]
        if !payload.moments.isEmpty { parts.append("\(payload.moments.count) 条动态") }
        if !payload.world.isEmpty { parts.append("\(payload.world.count) 条世界书") }
        // 表情和书也真写库了。不报出来的话，用户没法确认「自建表情回来了没有」。
        if let stickers = payload.stickers, !stickers.isEmpty {
            parts.append("\(stickers.count) 个表情")
        }
        if let books = payload.books, !books.isEmpty {
            parts.append("\(books.count) 本书")
        }

        let suffix = extras.isEmpty ? "" : "，以及" + extras.joined(separator: "、")
        return "恢复了 " + parts.joined(separator: "、") + suffix + "。"
    }
}
