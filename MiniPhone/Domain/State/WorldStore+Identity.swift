import Foundation

/// 角色改名、删除之后，世界状态里按名字存的那些东西要跟着搬。
///
/// `Companion` 用 uid 做身份，但 `WorldState` 里大部分数据是按**名字**做键的：
/// 记忆、好感度、心情、地点、日程、手机、火花、匿名提问、刷新计数、信、
/// 西瓜皮的私信与动态。角色一改名，这些条目全部变成孤儿——界面上表现为
/// 「记忆和好感度凭空清零」，而且永久留在 JSON 里占体积。
///
/// 删角色更糟：只删 `Companion` 的话，重建一个同名角色会直接继承前一个人的
/// 全部记忆和好感度，看着像灵异事件。
extension WorldStore {

    // MARK: - 改名

    /// 把 `oldName` 名下的世界数据整体搬到 `newName` 名下。
    ///
    /// 只在名字真的变了的时候调。搬法是「有就搬、目标已有就不覆盖」——
    /// 目标名下的数据是另一个人的，覆盖等于把别人的抹了。
    func renamePerson(from oldName: String, to newName: String) {
        let from = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty, from != to else { return }

        for index in state.people.indices where state.people[index].name == from {
            state.people[index].name = to
        }
        // 名字还冗余存在条目内部：事实的来源、心事的归属、评论的署名。
        // 只改 PersonMemory.name 的话，记忆页和心事页里仍旧显示旧名字。
        for index in state.people.indices {
            for fact in state.people[index].facts.indices where state.people[index].facts[fact].sourceName == from {
                state.people[index].facts[fact].sourceName = to
            }
            for voice in state.people[index].voices.indices where state.people[index].voices[voice].personName == from {
                state.people[index].voices[voice].personName = to
            }
        }
        for index in state.feed.indices {
            for comment in state.feed[index].comments.indices where state.feed[index].comments[comment].authorName == from {
                state.feed[index].comments[comment].authorName = to
            }
        }
        for index in state.characterDays.indices where state.characterDays[index].name == from {
            state.characterDays[index].name = to
        }
        for index in state.phones.indices where state.phones[index].owner == from {
            state.phones[index].owner = to
        }
        for index in state.questions.indices where state.questions[index].characterName == from {
            state.questions[index].characterName = to
        }
        for index in state.letters.indices where state.letters[index].fromName == from {
            state.letters[index].fromName = to
        }
        for index in state.feed.indices where state.feed[index].authorName == from {
            state.feed[index].authorName = to
        }
        for index in state.feedInbox.indices where state.feedInbox[index].companionName == from {
            state.feedInbox[index].companionName = to
        }
        for index in state.feedActivity.indices where state.feedActivity[index].companionName == from {
            state.feedActivity[index].companionName = to
        }

        moveKey(&state.moods, from: from, to: to)
        moveKey(&state.locations, from: from, to: to)
        moveKey(&state.affinity, from: from, to: to)
        moveKey(&state.couples, from: from, to: to)
        // `refreshTurns` 的键是页面（"shop" / "feed"），不是人名。
        // 以前把它一起搬，角色恰好叫 shop 时会把西瓜皮的刷新计数搬走。

        // 群成员表。成员改名了但表里还是旧名字，单聊就反查不到他在哪个群。
        // 先收集键再改：遍历字典的同时写它，Swift 那边是未定义行为。
        for group in Array(state.groups.keys) {
            guard var members = state.groups[group], members.contains(from) else { continue }
            if let index = members.firstIndex(of: from) { members[index] = to }
            state.groups[group] = members
        }
        // 改的是群名本身：键跟着换，成员各自那份群笔记的键也得换，
        // 否则记忆还在，只是再也读不出来了。
        if let members = state.groups.removeValue(forKey: from) {
            state.groups[to] = members
        }
        for index in state.people.indices {
            if let note = state.people[index].groupNotes.removeValue(forKey: from) {
                state.people[index].groupNotes[to] = note
            }
        }

        save()
        AppLog.storage.info("世界状态改名：\(from, privacy: .public) → \(to, privacy: .public)")
    }

    // MARK: - 清空

    /// 清空对话时一起清记忆条目。
    ///
    /// 只删消息的话，记忆页还留着一堆事实，模型在「空对话」里照样会提起旧事，
    /// 用户会以为没清干净。好感度保留——那是关系走到哪儿了，不是说过什么。
    func clearPersonMemory(named name: String) {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }

        if let index = state.people.firstIndex(where: { $0.name == target }) {
            state.people[index].facts.removeAll()
            state.people[index].voices.removeAll()
            state.people[index].summary = ""
            state.people[index].groupNotes.removeAll()
        }
        // 清的是群：成员各自那份群笔记也得清。
        // 遍历全部人物而不是成员名单——退群、改名之后名单里已经没有的人，
        // 身上仍留着这个群的笔记，按名单清会漏掉，群聊时照样被读进提示词。
        if state.groups[target] != nil {
            for index in state.people.indices {
                state.people[index].groupNotes.removeValue(forKey: target)
            }
        }
        state.characterDays.removeAll { $0.name == target }
        save()
    }

    // MARK: - 删除

    /// 删角色之前，把他名下的世界数据清干净。
    ///
    /// 帖子和私信一起删：他都不存在了，主页点进去是空的，
    /// 信息列表里留一条打不开的会话更奇怪。
    func purgePerson(named name: String) {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }

        state.people.removeAll { $0.name == target }
        state.characterDays.removeAll { $0.name == target }
        state.phones.removeAll { $0.owner == target }
        state.questions.removeAll { $0.characterName == target }
        state.letters.removeAll { $0.fromName == target }
        state.feed.removeAll { $0.authorName == target }
        // 他自己的帖子删了，他在别人帖子下的评论还在。评论只存署名不存 uid，
        // 留着会让详情页按名字反查、凭空长出一个 isFeedOnly 角色。
        for index in state.feed.indices {
            state.feed[index].comments.removeAll { $0.authorName == target }
        }
        state.feedInbox.removeAll { $0.companionName == target }
        state.feedActivity.removeAll { $0.companionName == target }

        state.moods.removeValue(forKey: target)
        state.locations.removeValue(forKey: target)
        state.affinity.removeValue(forKey: target)
        state.couples.removeValue(forKey: target)
        // 同上：刷新计数按页面存，不按人名。这里删会误伤同名的页面键。

        // 群：删的是群就整条删掉；删的是人就从所有群的成员名单里摘出去。
        // 留着名字的话，单聊反查时还会命中一个已经不存在的人。
        // 删的是群：成员各自那份「在这个群里」的笔记也要一起清。
        // 只删群账户的话，重建同名群时旧记忆会自己回来；
        // 清空群记忆那条路径（clearPersonMemory）已经处理过，删除这里漏了。
        let removedGroup = state.groups.removeValue(forKey: target) != nil
        if removedGroup {
            for index in state.people.indices {
                state.people[index].groupNotes.removeValue(forKey: target)
            }
        }
        for group in Array(state.groups.keys) {
            state.groups[group]?.removeAll { $0 == target }
        }

        save()
        AppLog.storage.info("世界状态清理：\(target, privacy: .public)")
    }

    /// 字典里换个键。目标已经有值就丢掉源值——同名不同人的数据不该合并。
    private func moveKey<T>(_ dict: inout [String: T], from: String, to: String) {
        guard let value = dict.removeValue(forKey: from) else { return }
        guard dict[to] == nil else { return }
        dict[to] = value
    }
}
