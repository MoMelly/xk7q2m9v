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
        moveKey(&state.refreshTurns, from: from, to: to)

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
        state.feedInbox.removeAll { $0.companionName == target }
        state.feedActivity.removeAll { $0.companionName == target }

        state.moods.removeValue(forKey: target)
        state.locations.removeValue(forKey: target)
        state.affinity.removeValue(forKey: target)
        state.couples.removeValue(forKey: target)
        state.refreshTurns.removeValue(forKey: target)

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
