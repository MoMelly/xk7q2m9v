import Foundation

/// 世界状态里「记下来的东西」：记忆条目的增删改、好感度、自由变量。
///
/// 从 `WorldStore` 里拆出来是因为主文件已经压到行数上限了。
/// 这一组方法的共同点是都在改 `people` / `affinity` / `variables`——
/// 全是「人对人的判断」，和日程、手机、音乐那些「设备上的事」不是一类。
extension WorldStore {

    // MARK: - 人物级记忆

    /// 事实挂在人名上：群聊里谁说的不影响单聊能不能想起来。
    func recordFact(person name: String, text: String, sourceName: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let index = state.ensurePerson(named: name)
        let already = state.people[index].facts.contains { $0.text == clean }
        guard !already else { return }

        state.people[index].facts.append(
            PersonFact(id: UUID(), text: clean, sourceName: sourceName, createdAt: Date())
        )
        if state.people[index].facts.count > 60 {
            state.people[index].facts.removeFirst(state.people[index].facts.count - 60)
        }
        save()
    }

    /// 整段替换概括。压缩的结果是「这几轮聊完，到现在为止的全部记忆」，
    /// 不是增量——用追加的话每压一次就多一份，1200 字的上限会被旧摘要挤满。
    func replaceMemorySummary(person name: String, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let index = state.ensurePerson(named: name)
        // 空串是编辑器里的「删掉这一条」。压缩路径在外面已经挡过空结果，
        // 这里再挡一次会让删除按钮看着生效、实际什么也没改。
        state.people[index].summary = String(clean.suffix(1200))
        save()
    }

    /// 读一个人（或一个群）已经攒下的记忆。没写过就是空串。
    ///
    /// 群记忆和人物记忆共用这一张表：群名也是一个「人名」，只是它的
    /// facts 和 summary 记的是群层面的事。这样单聊、群聊、记忆页读的是同一份。
    func memorySummary(for name: String) -> String {
        state.person(named: name)?.summary ?? ""
    }

    // MARK: - 群

    /// 群聊开场时同步一次成员表。
    ///
    /// 成员表要落在世界状态里，单聊才知道「他还在哪些群里」。
    /// 名单变了就整份换掉——群成员在界面上是可改的，留旧名字只会让
    /// 已经退群的人继续收到群记忆。
    func syncGroup(named group: String, members: [String]) {
        guard !group.isEmpty else { return }
        // 群名本身不算成员：它在单聊里会被当成一个人去查，查到的却是群。
        let roster = Array(Set(members.filter { !$0.isEmpty && $0 != group })).sorted()
        guard !roster.isEmpty, state.groups[group] != roster else { return }
        state.groups[group] = roster
        save()
    }

    /// 这个人在某个群里那一份记忆。群聊压缩时写，单聊和群聊都读。
    func setGroupNote(person name: String, group: String, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !group.isEmpty else { return }
        let index = state.ensurePerson(named: name)
        if clean.isEmpty {
            // 空串同样表示删除。留着空值会让群记忆页分出一栏永远空白的视角。
            state.people[index].groupNotes.removeValue(forKey: group)
        } else {
            state.people[index].groupNotes[group] = String(clean.suffix(1_200))
        }
        save()
    }

    /// 这个群里每个成员各自记下的那一份。key 是成员名，不含群本身。
    func groupNotes(in group: String) -> [String: String] {
        var result: [String: String] = [:]
        for person in state.people where person.name != group {
            guard let note = person.groupNotes[group],
                  !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            result[person.name] = note
        }
        return result
    }

    /// 群记忆页要分几栏：成员表里的每个人都有一栏，已经留下笔记但不在
    /// 成员表里的人也要有，否则那条笔记在界面上找不到出处。
    /// 不用 Set 合并——顺序随机会让每次重启分栏位置都不一样。
    func groupRoster(named group: String) -> [String] {
        var names = (state.groups[group] ?? []).filter { $0 != group }
        for name in groupNotes(in: group).keys.sorted() where !names.contains(name) {
            names.append(name)
        }
        return names
    }

    /// 删掉一条记错的事。
    ///
    /// 记忆页原本是完全只读的：手改会让记忆和实际发生过的事对不上。
    /// 但「记错了」和「想加一句」不是一回事——记错的那条必须能去掉，
    /// 否则之后每轮都会带着这个错，越聊越歪。
    func deleteFact(person name: String, id: UUID) {
        guard let index = state.people.firstIndex(where: { $0.name == name }) else { return }
        state.people[index].facts.removeAll { $0.id == id }
        save()
    }

    // MARK: - 好感度与变量

    /// 好感度。没设过的时候按聊天量给一个起点：加进来就认识，不算完全陌生。
    func affinity(for name: String) -> Int {
        guard !name.isEmpty else { return 0 }
        if let stored = state.affinity[name] { return stored }
        return 30
    }

    func setAffinity(_ value: Int, for name: String) {
        guard !name.isEmpty else { return }
        state.affinity[name] = max(0, min(100, value))
        save()
    }

    /// 聊完一轮推一格。幅度小是有意的：好感度要让长期行为慢慢显出来，
    /// 不是一句话就能跳到顶。
    func bumpAffinity(for name: String, by delta: Int = 1) {
        guard !name.isEmpty, delta != 0 else { return }
        state.affinity[name] = max(0, min(100, affinity(for: name) + delta))
        save()
    }

    func setVariable(_ value: String, for key: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanValue.isEmpty {
            state.variables.removeValue(forKey: cleanKey)
        } else {
            state.variables[cleanKey] = String(cleanValue.prefix(120))
        }
        save()
    }

    func removeVariable(_ key: String) {
        state.variables.removeValue(forKey: key)
        save()
    }

    /// 改一条记错的事。
    ///
    /// 只改文字，不改来源和时间：那条事实是哪次对话里长出来的，得留得住。
    /// 改空等于删。
    func updateFact(person name: String, id: UUID, text: String) {
        guard let personIndex = state.people.firstIndex(where: { $0.name == name }),
              let factIndex = state.people[personIndex].facts.firstIndex(where: { $0.id == id })
        else { return }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            state.people[personIndex].facts.remove(at: factIndex)
            save()
            return
        }
        state.people[personIndex].facts[factIndex].text = clean
        save()
    }

    /// 改一条心事的文字。改空等于删。
    func updateVoice(person name: String, id: UUID, text: String) {
        guard let personIndex = state.people.firstIndex(where: { $0.name == name }),
              let voiceIndex = state.people[personIndex].voices.firstIndex(where: { $0.id == id })
        else { return }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            state.people[personIndex].voices.remove(at: voiceIndex)
            save()
            return
        }
        state.people[personIndex].voices[voiceIndex].text = clean
        save()
    }

    /// 放下 / 重新捡起。放下和删掉不是一回事：放下的还留在列表里，只是不再提起。
    func setVoiceResolved(person name: String, id: UUID, resolved: Bool) {
        guard let personIndex = state.people.firstIndex(where: { $0.name == name }),
              let voiceIndex = state.people[personIndex].voices.firstIndex(where: { $0.id == id })
        else { return }
        state.people[personIndex].voices[voiceIndex].isResolved = resolved
        state.people[personIndex].voices[voiceIndex].resolvedAt = resolved ? Date() : nil
        save()
    }

    /// 改某一天的概括。那天说了什么写错了，能就地改。
    func updateDaySummary(named name: String, dateKey: String, summary: String) {
        guard let index = state.characterDays.firstIndex(where: {
            $0.name == name && $0.dateKey == dateKey
        }) else { return }
        state.characterDays[index].summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    // MARK: - 匿名提问箱

    func questions(for name: String) -> [AnonymousQuestion] {
        state.questions
            .filter { $0.characterName == name }
            .sorted { $0.askedAt > $1.askedAt }
    }

    /// 投一个问题进去。返回它的 id，用来之后把答案填回来。
    ///
    /// 代号按这个角色收到过的第几个问题来编，不是全站计数：
    /// 「匿名 3 号」出现在他的页面上才有意义，跨角色计数只会编到几百号。
    @discardableResult
    func appendQuestion(characterName: String, text: String) -> UUID? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let count = state.questions.filter { $0.characterName == characterName }.count
        let item = AnonymousQuestion(
            id: UUID(),
            characterName: characterName,
            asker: "匿名 \(count + 1) 号",
            text: clean,
            answer: "",
            askedAt: Date(),
            answeredAt: nil
        )
        state.questions.insert(item, at: 0)
        if state.questions.count > 80 {
            state.questions.removeLast(state.questions.count - 80)
        }
        save()
        return item.id
    }

    /// 填上回答，同时把这一问一答记进他的记忆。
    ///
    /// 记忆里不写「匿名 3 号问的」——他自己也不知道是谁问的，
    /// 写进去会让他以为记得有这么一个人。
    func answerQuestion(id: UUID, answer: String) {
        guard let index = state.questions.firstIndex(where: { $0.id == id }) else { return }
        let clean = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        state.questions[index].answer = clean
        state.questions[index].answeredAt = clean.isEmpty ? nil : Date()
        let name = state.questions[index].characterName
        let question = state.questions[index].text
        save()

        guard !clean.isEmpty else { return }
        recordFact(
            person: name,
            text: "有人在提问箱里问「\(question)」，我答：\(clean)",
            sourceName: "匿名提问箱"
        )
    }

    func deleteQuestion(id: UUID) {
        state.questions.removeAll { $0.id == id }
        save()
    }
}
