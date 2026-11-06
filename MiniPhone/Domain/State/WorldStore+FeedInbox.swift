import Foundation

extension WorldStore {
    /// 角色主动发来一条私信或转帖。
    ///
    /// 一次写两处：inbox 给界面看，activity 给记忆层看。只写 inbox 的话，
    /// 角色在「信息」里聊天时不会知道自己刚才在西瓜皮干过什么。
    /// 反过来说，inbox 本身不进提示词——同一件事存两份，下次会像复读。
    func deliverFeedInbox(_ item: FeedInboxItem) {
        guard !state.feedInbox.contains(where: { $0.id == item.id }) else { return }
        state.feedInbox.insert(item, at: 0)
        appendFeedActivity(
            kind: item.kind,
            companionName: item.companionName,
            summary: item.kind == .postShare
                ? "《\(item.noteTitle)》· \(item.message)"
                : item.message,
            at: item.createdAt
        )
        save()
    }

    func markFeedInboxRead(_ id: UUID) {
        guard let index = state.feedInbox.firstIndex(where: { $0.id == id }) else { return }
        guard !state.feedInbox[index].isRead else { return }
        state.feedInbox[index].isRead = true
        save()
    }

    /// 用户从作者主页主动开的私信会话。一个作者只开一条，重复点回到同一段。
    ///
    /// 不写 activity：这是「我」先开的口，不算角色做过的事，记忆层不该记成他的动作。
    func openFeedThread(companionUID: String, companionName: String) -> FeedInboxItem {
        if let existing = state.feedInbox.first(where: {
            $0.kind == .directMessage && $0.companionUID == companionUID
        }) {
            return existing
        }
        let item = FeedInboxItem(
            id: UUID(),
            kind: .directMessage,
            companionUID: companionUID,
            companionName: companionName,
            noteID: nil,
            noteTitle: "",
            noteBody: "",
            noteTag: "",
            coverSeed: 0,
            message: "你们还没说过话，先打个招呼吧。",
            createdAt: Date(),
            isRead: true,
            threadID: UUID()
        )
        state.feedInbox.insert(item, at: 0)
        save()
        return item
    }

    /// 用户分享帖子之后，把会话列表的预览换成这次分享。
    /// 不写 activity：这是「我」的动作，不该记成角色做过的事。
    func updateFeedThreadPreview(threadID: UUID, message: String) {
        guard let index = state.feedInbox.firstIndex(where: { $0.threadID == threadID }) else { return }
        state.feedInbox[index].message = message
        state.feedInbox[index].createdAt = Date()
        save()
    }

    /// 截图状态下给市集铺几件商品，正常启动不调用。
    func seedPreviewShop() {
        guard state.shop.isEmpty else { return }
        let samples: [(String, Int, String, String, String, Int)] = [
            ("薄壁玻璃杯", 3900, "透光好看，拿在手里很轻", "你说想换个轻一点的杯子", "家居", 731),
            ("棉麻桌布", 8900, "米白偏暖，洗过会更软", "窗台收拾干净了", "家居", 264),
            ("小台灯", 12900, "暖光两档，不刺眼", "晚上想在桌边看会儿书", "灯具", 918),
            ("牛皮便签本", 2600, "可以撕，纸不洇墨", "你说想随手记点东西", "文具", 455)
        ]
        state.shop = samples.map { item in
            ShopItem(
                id: UUID(),
                title: item.0,
                priceCents: item.1,
                note: item.2,
                reason: item.3,
                category: item.4,
                imageSeed: item.5,
                addedAt: Date(),
                inCart: false
            )
        }
        save()
    }

    /// 对话里聊到的新内容也补一条索引，让别的 App 里聊天时能接上。
    /// 只记「围绕哪篇帖子聊了什么」，逐句消息已经在 StoredMessage 里，不重复存。
    func appendFeedActivity(
        kind: FeedInboxKind,
        companionName: String,
        summary: String,
        at date: Date = Date()
    ) {
        let clean = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.feedActivity.append(
            FeedActivity(
                id: UUID(),
                kind: kind,
                companionName: companionName,
                summary: String(clean.prefix(120)),
                createdAt: date
            )
        )
        // 提示词只取最近五条，留 40 条够回溯，再多只会把存档撑大。
        if state.feedActivity.count > 40 {
            state.feedActivity.removeFirst(state.feedActivity.count - 40)
        }
        save()
    }
}
