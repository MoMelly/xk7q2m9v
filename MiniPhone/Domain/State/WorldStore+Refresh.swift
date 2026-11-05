import Foundation

/// 刷新流：把模型这一轮带回来的商品、笔记、评论写进世界状态。
///
/// 拆在扩展里是因为 `WorldStore` 本身已经承担了日程、记忆、心声三块，
/// 再往里塞会让这个文件变成所有东西的杂物间。扩展只读写 `state`，
/// 不碰文件路径和初始化。
extension WorldStore {
    // MARK: - 刷新流

    /// 每聊完一轮给所有启用的页面计数 +1。
    func noteTurn(pages: [RefreshPage]) {
        for page in pages {
            state.refreshTurns[page.rawValue, default: 0] += 1
        }
        save()
    }

    /// 刷新真的发生后把对应页面的计数清零，并挂一条待显示的提示。
    ///
    /// 提示放在这里而不是聊天层：刷新是在落库时发生的，
    /// 谁触发的刷新都该有这一下，不该由界面自己判断。
    func markRefreshed(_ pages: Set<RefreshPage>, at date: Date = Date()) {
        for page in pages {
            state.refreshTurns[page.rawValue] = 0
        }
        state.lastRefreshAt = date

        showNotices(pages.sorted { $0.rawValue < $1.rawValue })
        save()
    }

    /// 把这一轮带回来的商品写进推荐流。
    ///
    /// 同名商品不重复推；没有价格的直接丢掉——没有价格就没法显示成商品卡。
    /// 返回真正写进去的条数，调用方据此决定要不要清掉刷新计数。
    @discardableResult
    func applyShopDrafts(_ drafts: [ReplyEnvelope.ShopDraft], limit: Int) -> Int {
        var added = 0
        for draft in drafts {
            guard added < limit else { break }
            guard let title = draft.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { continue }
            guard !state.shop.contains(where: { $0.title == title }) else { continue }

            let cents = Int(((draft.price ?? 0) * 100).rounded())
            guard cents > 0 else { continue }

            state.shop.insert(
                ShopItem(
                    id: UUID(),
                    title: String(title.prefix(40)),
                    priceCents: cents,
                    note: String((draft.note ?? "").prefix(40)),
                    reason: String((draft.reason ?? "").prefix(60)),
                    category: String((draft.category ?? "").prefix(10)),
                    imageSeed: StableSeed.of(title),
                    addedAt: Date(),
                    inCart: false
                ),
                at: 0
            )
            added += 1
        }

        // 旧的往下沉，用户翻不到底会让「刷新」失去意义。
        if state.shop.count > 30 {
            state.shop.removeLast(state.shop.count - 30)
        }
        return added
    }

    /// 把这一轮带回来的笔记写进小红书。
    @discardableResult
    func applyFeedDrafts(
        _ drafts: [ReplyEnvelope.FeedDraft],
        author: String,
        authorUID: String?,
        limit: Int
    ) -> Int {
        var added = 0
        for draft in drafts {
            guard added < limit else { break }
            guard let title = draft.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { continue }
            guard !state.feed.contains(where: { $0.title == title }) else { continue }

            let body = (draft.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (draft.author ?? author).trimmingCharacters(in: .whitespacesAndNewlines)
            let comments = (draft.comments ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(2)
                .enumerated()
                .map { index, text in
                    NoteComment(
                        id: UUID(),
                        authorName: "网友",
                        text: String(text.prefix(60)),
                        postedAt: Date().addingTimeInterval(Double(index) * 60),
                        isCharacter: false
                    )
                }

            state.feed.insert(
                FeedNote(
                    id: UUID(),
                    authorName: String((name.isEmpty ? author : name).prefix(12)),
                    // 只有名字和当前角色对得上时才认作角色本人，否则点进主页会跳错人。
                    authorUID: (name.isEmpty || name == author) ? authorUID : nil,
                    title: String(title.prefix(40)),
                    body: String(body.prefix(400)),
                    tag: String((draft.tag ?? "").prefix(16)),
                    likes: Int.random(in: 3...260),
                    comments: comments,
                    postedAt: Date(),
                    coverSeed: StableSeed.of(title)
                ),
                at: 0
            )
            added += 1
        }

        if state.feed.count > 40 {
            state.feed.removeLast(state.feed.count - 40)
        }
        return added
    }

    /// 加购 / 移出购物车。
    func setCart(itemID: UUID, inCart: Bool) {
        guard let index = state.shop.firstIndex(where: { $0.id == itemID }) else { return }
        state.shop[index].inCart = inCart
        save()
    }

    /// 用户自己在小红书发的笔记。
    ///
    /// `authorUID` 留空表示「我发的」，界面上不当成角色主页入口。
    func publishNote(title: String, body: String, tag: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        state.feed.insert(
            FeedNote(
                id: UUID(),
                authorName: "我",
                authorUID: nil,
                title: String(cleanTitle.prefix(40)),
                body: String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400)),
                tag: String(tag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16)),
                likes: 0,
                comments: [],
                postedAt: Date(),
                coverSeed: StableSeed.of(cleanTitle)
            ),
            at: 0
        )
        save()
    }

    /// 用户自己在某条笔记下面补一句。
    func addComment(noteID: UUID, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let index = state.feed.firstIndex(where: { $0.id == noteID }) else { return }

        state.feed[index].comments.append(
            NoteComment(
                id: UUID(),
                authorName: "我",
                text: String(clean.prefix(120)),
                postedAt: Date(),
                isCharacter: false
            )
        )
        save()
    }

    /// 后续轮次补上的评论：按标题找最新那条笔记，找不到就跳过。
    ///
    /// 用标题而不是 id，是因为模型写不出自己上一轮生成的 UUID；
    /// 标题重复的概率在实际使用里很低，真撞了也只是评到另一条同类内容上。
    @discardableResult
    func applyFeedComments(_ drafts: [ReplyEnvelope.FeedComment], limit: Int) -> Int {
        var added = 0
        for draft in drafts {
            guard added < limit else { break }
            guard let text = draft.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { continue }

            let targetTitle = (draft.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let index = state.feed.firstIndex { note in
                targetTitle.isEmpty
                    ? note.comments.count < 3
                    : note.title.contains(targetTitle) || targetTitle.contains(note.title)
            }
            guard let index else { continue }

            state.feed[index].comments.append(
                NoteComment(
                    id: UUID(),
                    authorName: String((draft.author ?? "网友").prefix(12)),
                    text: String(text.prefix(60)),
                    postedAt: Date(),
                    isCharacter: !(draft.author ?? "").isEmpty
                )
            )
            added += 1
        }
        if added > 0 { save() }
        return added
    }
}
