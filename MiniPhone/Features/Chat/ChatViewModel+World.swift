import SwiftUI
import SwiftData

/// `ChatViewModel` 里「把这一轮的结果写回世界状态」的那一组。
///
/// 从主文件拆出来的：主文件已经顶到 600 行上限，而这几块和发请求、拼提示词
/// 不是同一件事——它们只改 `WorldStore` 和落库，读的时候用不着往上翻几百行。
extension ChatViewModel {

    /// 把这一轮记进角色当天的那一页。
    ///
    /// 日程本身是本地排出来的，聊过之后才盖上「这天说过话」的章，
    /// 并把模型给的 dayLog 挂上去。角色之后说「昨天我们聊到……」靠的就是它。
    func recordDay(
        _ meta: ReplyEnvelope.Meta?,
        for character: Companion,
        speakers: [String] = [],
        context: ModelContext? = nil
    ) {
        let world = WorldStore.shared
        let log = meta?.dayLog?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 群主，加上这一轮真的开口的成员，各自记一天。
        // 只记群主的话，群里其他人永远没有当天日程，好感度也一直停在默认值。
        var targets: [(name: String, wake: Int, sleep: Int)] = [
            (character.name, character.wakeHour, character.sleepHour)
        ]
        if !speakers.isEmpty, let context {
            let roster = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
            for name in Set(speakers).sorted() where name != character.name {
                let mate = roster.first { $0.name == name }
                targets.append((
                    name,
                    mate?.wakeHour ?? character.wakeHour,
                    mate?.sleepHour ?? character.sleepHour
                ))
            }
        }

        for target in targets {
            world.ensureCharacterDay(
                named: target.name,
                wakeHour: target.wake,
                sleepHour: target.sleep,
                replies: character.totalReplies
            )
            world.noteCharacterChat(named: target.name, summary: log)
            world.markCoupleDay(fromMe: false, partner: target.name)
            // 说过一轮就往前挪一格。模型给了具体的心情转折也不额外加，
            // 否则「聊得开心」比「天天来」涨得快，好感度会集中爆发在几次长对话里。
            world.bumpAffinity(for: target.name, by: 1)
        }
    }

    /// 状态块里带回来的增量统一写进 WorldStore。
    /// 群聊里发生的事按所有相关人物归档，所以回到单聊时读得到同一份记忆。
    func applySideEffects(
        _ meta: ReplyEnvelope.Meta?,
        names: [String],
        speakers: [String],
        character: Companion,
        context: ModelContext
    ) {
        guard let meta else { return }
        let world = WorldStore.shared

        // 心情和心事归「这一轮真正开口的人」。群聊里只有一个人说话时写给他；
        // 几个人同时说、或者根本分不清（旁白、动作），才回落到会话自己的角色。
        // 原来一律写给群主，阿岚的心情会变成整个群的心情，柏川在单聊里
        // 永远读不到自己那句心事。
        let owners = speakers.filter { !$0.isEmpty }
        let owner = owners.count == 1 ? (owners.first ?? character.name) : character.name

        if let raw = meta.mood, let mood = Mood(rawValue: raw) {
            world.updateMood(mood, reason: meta.moodReason ?? "", source: .chat, for: owner)
        }
        if let voice = meta.voice {
            world.appendVoice(person: owner, text: voice, source: .chat)
        }
        if let memory = meta.memory {
            // 有明确说话人时只记给他。原先分给群里每一个人，
            // 结果是「柏川记得阿岚说过的话」，而且记成自己说的。
            for name in (owners.isEmpty ? names : owners) {
                world.recordFact(person: name, text: memory, sourceName: owner)
            }
        }
        if let note = meta.scheduleNote, !note.isEmpty {
            // 日程是「谁今天干了什么」，只记给说话的人。
            world.recordFact(person: owner, text: "日程：\(note)", sourceName: owner)
        }
        if let moment = meta.moment, !moment.isEmpty {
            // 动态挂在这个会话的角色上：`characterUID` 和 `characterName` 必须
            // 是同一个人的，改其中一个就会点进一张空主页。
            context.insert(
                MomentPost(
                    characterUID: character.uid,
                    characterName: character.name,
                    text: moment
                )
            )
        }
        if let raw = meta.voiceResolvedID, let id = UUID(uuidString: raw) {
            world.resolveVoice(id: id)
        }
    }

    /// 把这一轮带回来的页面增量写进世界状态。
    ///
    /// 判定过要刷、模型却什么都没给，是正常会发生的（它觉得最近没线索）。
    /// 这种情况不清零计数，下一轮还能再判一次，不会白等六轮。
    func applyRefresh(
        _ meta: ReplyEnvelope.Meta?,
        refresh: RefreshRequest?,
        enabledPages: [RefreshPage],
        for character: Companion
    ) {
        let world = WorldStore.shared

        guard let refresh, let meta else {
            world.noteTurn(pages: enabledPages)
            return
        }

        var added = 0
        if refresh.wantsShop {
            added += world.applyShopDrafts(meta.shop ?? [], limit: refresh.shopLimit)
        }
        if refresh.wantsFeed {
            added += world.applyFeedDrafts(
                meta.feed ?? [],
                author: character.name,
                authorUID: character.uid.uuidString,
                limit: refresh.feedLimit
            )
            added += world.applyFeedComments(meta.feedComments ?? [], limit: refresh.commentLimit)
        }

        if added > 0 {
            world.markRefreshed(refresh.pages)
            // App 不在前台时补一条本地通知；在前台由外壳弹玻璃横幅，不走系统通知。
            ReplyNotifier.notifyRefresh(text: refresh.notices.joined(separator: "\n"))
        } else {
            world.noteTurn(pages: enabledPages)
        }
    }

    /// 群聊成员的设定卡。
    ///
    /// 群成员的名单只是一串名字，模型看不出这些名字各自是什么人，
    /// 于是用同一个语气写所有人——群里就只剩一个声音。按名字去库里找同名角色，
    /// 各带一小段人设（截到 120 字，多人时不然提示词会长到离谱）。
    func groupMates(for character: Companion, context: ModelContext) -> [GroupMate] {
        guard character.isGroup else { return [] }
        let roster = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
        return relatedNames(for: character)
            .filter { $0 != character.name }
            .compactMap { name in
                guard let mate = roster.first(where: { $0.name == name }) else { return nil }
                let persona = mate.persona
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                return GroupMate(name: name, persona: String(persona.prefix(120)), uid: mate.uid)
            }
    }

    /// 这一轮牵扯到的人。
    ///
    /// **第一个一定是这个会话自己的角色**：`WorldStore.context` 用 `names.first`
    /// 决定读谁的日程、手机、心情、好感度，原来是 `Array(Set(names))`——
    /// Set 的顺序每个进程都不一样，重启一次提示词里的「他」就换了个人。
    func relatedNames(for character: Companion) -> [String] {
        var members = [character.name]
        if character.isGroup {
            members.append(contentsOf: character.membersNote
                .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == "\n" })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        }
        // 其余成员按名字排序，同一个群每次拼出来都是同一个顺序。
        let others = Set(members).filter { $0 != character.name }.sorted()
        return [character.name] + others
    }
}
