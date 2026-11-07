import Foundation

/// 模型给的东西不能信类型。
///
/// 它可能把 `unread` 写成 `"1"`、把 `pinned` 漏掉、把数组写成 null。
/// 标准 `decodeIfPresent` 遇到类型不对就整个对象失败，一条小错会把整台手机丢掉，
/// 所以每个键单独软解：拿不到就用默认值，其余照常。
private func soft<T: Decodable, K: CodingKey>(
    _ type: T.Type,
    _ container: KeyedDecodingContainer<K>,
    _ key: K,
    _ fallback: T
) -> T {
    ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
}

/// 他的手机里有什么。
///
/// 内容全部来自模型按一块固定模板填出来的东西，不是本机真实数据。
/// 所以时间一律是直接显示的字符串（"21:06"），不出现时间戳 —— 省掉一层格式化，
/// 也避免时区和「昨天」这种相对时间算错。
struct CharacterPhone: Codable {
    var owner: String = ""
    var generatedAt: Date?

    var chats: [PhoneChat] = []
    var album: [PhonePhoto] = []
    var notes: [PhoneNote] = []
    var calls: [PhoneCall] = []
    var shopping: [PhoneShopping] = []
    var history: [PhoneBrowse] = []
    var usage: [PhoneUsage] = []
    var secrets: [PhoneSecret] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case owner, generatedAt, chats, album, notes, calls, shopping, history, usage, secrets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        owner = soft(String.self, c, .owner, "")
        generatedAt = (try? c.decodeIfPresent(Date.self, forKey: .generatedAt)) ?? nil
        chats = soft([PhoneChat].self, c, .chats, [])
        album = soft([PhonePhoto].self, c, .album, [])
        notes = soft([PhoneNote].self, c, .notes, [])
        calls = soft([PhoneCall].self, c, .calls, [])
        shopping = soft([PhoneShopping].self, c, .shopping, [])
        history = soft([PhoneBrowse].self, c, .history, [])
        usage = soft([PhoneUsage].self, c, .usage, [])
        secrets = soft([PhoneSecret].self, c, .secrets, [])
    }

    /// 一条内容都没有的时候界面上要显示「还没生成」。
    var isEmpty: Bool {
        chats.isEmpty && notes.isEmpty && calls.isEmpty && album.isEmpty && secrets.isEmpty
    }
}

// MARK: - 微信

struct PhoneChat: Codable, Identifiable {
    var name: String = ""
    /// 备注：家人 / 同事 / 外卖。名字下面那行小字。
    var relation: String = ""
    var preview: String = ""
    var time: String = ""
    var unread: Int = 0
    var pinned: Bool = false
    var lines: [PhoneLine] = []

    var id: String { name + "|" + relation }

    init() {}
    init(name: String, relation: String = "", lines: [PhoneLine] = []) {
        self.name = name
        self.relation = relation
        self.lines = lines
        self.preview = lines.last?.text ?? ""
        self.time = lines.last?.time ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case name, relation, preview, time, unread, pinned, lines
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = soft(String.self, c, .name, "")
        relation = soft(String.self, c, .relation, "")
        time = soft(String.self, c, .time, "")
        unread = soft(Int.self, c, .unread, 0)
        pinned = soft(Bool.self, c, .pinned, false)
        lines = soft([PhoneLine].self, c, .lines, [])
        let given = soft(String.self, c, .preview, "")
        preview = given.isEmpty ? (lines.last?.text ?? "") : given
        if time.isEmpty { time = lines.last?.time ?? "" }
    }
}

struct PhoneLine: Codable, Identifiable {
    /// true 表示这句是他自己发出去的。
    var fromMe: Bool = false
    var text: String = ""
    var time: String = ""

    var id: String { time + "|" + text }

    init(fromMe: Bool, text: String, time: String = "") {
        self.fromMe = fromMe
        self.text = text
        self.time = time
    }

    private enum CodingKeys: String, CodingKey { case fromMe, text, time }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 模型有时把 fromMe 写成 "我" / "对方" / "我发的"，两种都认。
        if let flag = (try? c.decodeIfPresent(Bool.self, forKey: .fromMe)) ?? nil {
            fromMe = flag
        } else {
            let word = soft(String.self, c, .fromMe, "")
            fromMe = ["我", "我发的", "true", "yes", "me"].contains(word.lowercased())
        }
        text = soft(String.self, c, .text, "")
        time = soft(String.self, c, .time, "")
    }
}

// MARK: - 相册

struct PhonePhoto: Codable, Identifiable {
    /// 画的是哪种静物，取 `MockPhotoSubject` 的序号。认不出来就按 seed 落一张。
    var seed: Int = 0
    var caption: String = ""
    var takenAt: String = ""

    var id: String { "\(seed)-\(caption)-\(takenAt)" }

    private enum CodingKeys: String, CodingKey { case seed, caption, takenAt }

    init(seed: Int, caption: String, takenAt: String = "") {
        self.seed = seed
        self.caption = caption
        self.takenAt = takenAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seed = soft(Int.self, c, .seed, 0)
        caption = soft(String.self, c, .caption, "")
        takenAt = soft(String.self, c, .takenAt, "")
    }
}

// MARK: - 备忘录

struct PhoneNote: Codable, Identifiable {
    var title: String = ""
    var body: String = ""
    var editedAt: String = ""

    var id: String { title + "|" + editedAt }

    private enum CodingKeys: String, CodingKey { case title, body, editedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = soft(String.self, c, .title, "")
        body = soft(String.self, c, .body, "")
        editedAt = soft(String.self, c, .editedAt, "")
    }
}

// MARK: - 通话

struct PhoneCall: Codable, Identifiable {
    var name: String = ""
    /// 呼入 / 呼出 / 未接。
    var kind: String = ""
    var duration: String = ""
    var time: String = ""

    var id: String { name + "|" + time + "|" + kind }

    /// 未接在界面上是红的，别的都是常规色。
    var isMissed: Bool {
        kind.contains("未接") || kind.lowercased().contains("missed")
    }

    private enum CodingKeys: String, CodingKey { case name, kind, duration, time }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = soft(String.self, c, .name, "")
        kind = soft(String.self, c, .kind, "呼入")
        duration = soft(String.self, c, .duration, "")
        time = soft(String.self, c, .time, "")
    }
}

// MARK: - 购物清单

struct PhoneShopping: Codable, Identifiable {
    var title: String = ""
    var price: String = ""
    /// 购物车 / 已下单 / 已签收。
    var status: String = ""
    var addedAt: String = ""

    var id: String { title + "|" + addedAt }

    private enum CodingKeys: String, CodingKey { case title, price, status, addedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = soft(String.self, c, .title, "")
        price = soft(String.self, c, .price, "")
        status = soft(String.self, c, .status, "购物车")
        addedAt = soft(String.self, c, .addedAt, "")
    }
}

// MARK: - 浏览记录

struct PhoneBrowse: Codable, Identifiable {
    var title: String = ""
    var site: String = ""
    var time: String = ""

    var id: String { title + "|" + time }

    private enum CodingKeys: String, CodingKey { case title, site, time }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = soft(String.self, c, .title, "")
        site = soft(String.self, c, .site, "")
        time = soft(String.self, c, .time, "")
    }
}

// MARK: - 应用时长

struct PhoneUsage: Codable, Identifiable {
    var app: String = ""
    var minutes: Int = 0
    /// 一句说明他拿这个 App 干了什么。
    var note: String = ""

    var id: String { app }

    private enum CodingKeys: String, CodingKey { case app, minutes, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = soft(String.self, c, .app, "")
        minutes = soft(Int.self, c, .minutes, 0)
        note = soft(String.self, c, .note, "")
    }

    var display: String {
        minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟"
    }
}

// MARK: - 私密

/// 他没说出口的事。
///
/// 两档：`secret` 是瞒着你的事（准备了什么、瞒下了什么麻烦），
/// `private` 是只属于两个人的私密记录，默认收起，设置里打开才看得到。
/// 写到哪一步交给角色卡和模型，这里只定字段。
struct PhoneSecret: Codable, Identifiable {
    var kind: String = "secret"
    var title: String = ""
    var text: String = ""
    var time: String = ""

    var id: String { title + "|" + time }

    var isPrivate: Bool { kind == "private" || kind == "私密" }
    var kindLabel: String { isPrivate ? "私密" : "瞒着你" }

    private enum CodingKeys: String, CodingKey { case kind, title, text, time }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = soft(String.self, c, .kind, "secret")
        title = soft(String.self, c, .title, "")
        text = soft(String.self, c, .text, "")
        time = soft(String.self, c, .time, "")
    }
}
