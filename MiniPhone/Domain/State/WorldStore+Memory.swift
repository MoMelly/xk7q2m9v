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

    func appendMemorySummary(person name: String, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let index = state.ensurePerson(named: name)
        let merged = state.people[index].summary.isEmpty
            ? clean
            : state.people[index].summary + "\n" + clean
        state.people[index].summary = String(merged.suffix(1200))
        save()
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

    /// 整段替换概括。之前只有追加（压缩时接在后面），改一个字就得删整份。
    func replaceMemorySummary(person name: String, text: String) {
        guard let index = state.people.firstIndex(where: { $0.name == name }) else { return }
        state.people[index].summary = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
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
}
