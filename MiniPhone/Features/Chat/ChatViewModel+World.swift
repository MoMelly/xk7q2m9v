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
        //
        // 群自己不排日程：「群今天去了便利店」不是一句能成立的话，
        // 那份数据只会在记忆页变成一条对不上人的记录。
        var targets: [(name: String, wake: Int, sleep: Int)] = []
        if !character.isGroup {
            targets.append((character.name, character.wakeHour, character.sleepHour))
        }
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
        spoken: [String] = [],
        character: Companion,
        context: ModelContext
    ) {
        guard let meta else { return }
        let world = WorldStore.shared

        // 这一轮谁在说、说了几句。`spoken` 是有序且带重复的，用来挑
        // 「说话最多的那个人」；`speakers` 只是去了重的名单。
        let owners = speakers.filter { !$0.isEmpty }
        let owner = Self.mostFrequent(spoken) ?? (owners.count == 1 ? (owners.first ?? character.name) : character.name)

        // 群聊没解析出任何说话人时，owner 会退到群名上。心情、心事、日程和
        // 个人事实都是「一个人」才有的状态，写成「周末饭局今天有点累」既对不上人，
        // 之后单聊查那个成员也永远读不到。这种轮次只留群层面的共同记忆。
        let hasSpeaker = !character.isGroup || owners.contains(owner)

        if hasSpeaker, let raw = meta.mood, let mood = Mood(rawValue: raw) {
            world.updateMood(mood, reason: meta.moodReason ?? "", source: .chat, for: owner)
        }

        if hasSpeaker, let voice = meta.voice, !voice.isEmpty {
            if character.isGroup {
                // 群聊的心事按发言人分。原来整条写给群主，结果群里
                // 每个人都只有群主一个心情，别人在单聊里永远读不到自己的心事。
                let items = Self.parseGroupVoices(
                    voice,
                    allowed: Set(owners),
                    fallback: owner
                )
                for item in items.prefix(2) {
                    world.appendVoice(person: item.name, text: item.text, source: .chat)
                }
            } else {
                world.appendVoice(person: character.name, text: voice, source: .chat)
            }
        }

        if let memory = meta.memory {
            // 群聊没解析出说话人时只记群名下那一条：这句话确实在群里发生过，
            // 但不能凭空摊给名单上的每个人。单聊照旧记给会话本人。
            let targets: [String]
            if character.isGroup {
                targets = owners.isEmpty ? [character.name] : owners
            } else {
                targets = [names.first ?? character.name]
            }
            for name in targets where !name.isEmpty {
                world.recordFact(person: name, text: memory, sourceName: owner)
            }
            // 群里共同发生的事还得记一份在群名下，否则单聊时读不到。
            if character.isGroup, !character.name.isEmpty, !owners.isEmpty {
                world.recordFact(person: character.name, text: memory, sourceName: owner)
            }
        }
        if hasSpeaker, let note = meta.scheduleNote, !note.isEmpty {
            // 日程是「谁今天干了什么」，只记给说话的人。
            world.recordFact(person: owner, text: "日程：\(note)", sourceName: owner)
        }
        if let moment = meta.moment, !moment.isEmpty, !character.isGroup {
            // 动态挂在这个会话的角色上：`characterUID` 和 `characterName` 必须
            // 是同一个人的，改其中一个就会点进一张空主页。
            //
            // 群聊不产动态：动态是「一个人的号」，一个群没有自己的主页，
            // 挂到群主名下就变成群主替所有人发心情。
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

    /// 挑出现次数最多的那个名字。并列时取最早出现的，
    /// 不能让一次并列把「这一轮谁在主导」判给随机的一个人。
    private static func mostFrequent(_ items: [String]) -> String? {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (index, item) in items.enumerated() {
            counts[item, default: 0] += 1
            if firstSeen[item] == nil { firstSeen[item] = index }
        }
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return (firstSeen[lhs.key] ?? 0) > (firstSeen[rhs.key] ?? 0)
        }?.key
    }

    /// 群聊心事拆解。
    ///
    /// 模型有时给一行「名字：内容」，有时给几行，有时干脆只给一句不带名字。
    /// 三种都收：认得出名字、而且名字确实在这轮开过口的人里，就记给他；
    /// 认不出、或者名字对不上，落到这一轮说话最多的人头上。
    private static func parseGroupVoices(
        _ raw: String,
        allowed: Set<String>,
        fallback: String
    ) -> [(name: String, text: String)] {
        let rows = raw
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result: [(name: String, text: String)] = []
        for row in rows {
            guard let index = row.firstIndex(where: { $0 == "：" || $0 == ":" }) else {
                push(&result, name: fallback, text: row)
                continue
            }
            let name = String(row[row.startIndex..<index]).trimmingCharacters(in: .whitespaces)
            let body = String(row[row.index(after: index)...]).trimmingCharacters(in: .whitespaces)
            if allowed.contains(name), !body.isEmpty {
                push(&result, name: name, text: body)
            } else if !body.isEmpty {
                push(&result, name: fallback, text: row)
            }
        }
        return result
    }

    /// 一条心事最多留 40 字。潜台词本来就不该是一段独白，
    /// 写长了会挤占提示词里「还没放下的心事」那四条的位置。
    private static func push(
        _ list: inout [(name: String, text: String)],
        name: String,
        text: String
    ) {
        let clean = text
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n「」\"'“”"))
        guard !clean.isEmpty, !name.isEmpty else { return }
        guard !list.contains(where: { $0.name == name && $0.text == clean }) else { return }
        list.append((name, String(clean.prefix(40))))
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
        let world = WorldStore.shared
        let now = Date()
        let hour = CharacterClock.calendar.component(.hour, from: now)
        return relatedNames(for: character)
            .filter { $0 != character.name }
            .compactMap { name in
                guard let mate = roster.first(where: { $0.name == name }) else { return nil }
                let persona = mate.persona
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                let mood = world.mood(for: name)
                let location = world.location(for: name)
                return GroupMate(
                    name: name,
                    persona: String(persona.prefix(120)),
                    uid: mate.uid,
                    mood: mood?.mood.label ?? "",
                    location: location,
                    schedule: world.todaySchedule(for: name)?
                        .items.map(\.title).joined(separator: "、") ?? "",
                    // 没存过就写 -1。`affinity(for:)` 的默认 30 是「刚认识」，
                    // 写进群里会让所有人看起来都停在同一个刻度上。
                    affinity: world.state.affinity[name] ?? -1,
                    conditions: WorldBookResolver.Conditions.build(
                        hour: hour,
                        mood: mood?.mood,
                        location: location,
                        since: mate.createdAt,
                        now: now
                    )
                )
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
