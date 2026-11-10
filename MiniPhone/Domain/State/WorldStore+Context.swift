import Foundation

/// 交给提示词的只读快照怎么拼。
///
/// 从 `WorldStore.swift` 拆出来：主文件当时正好顶到 600 行，再写一行就挂。
/// 内容上这一块也确实独立——它只读世界状态，不改任何东西，
/// 和「写心情、写记忆、写日程」那些不是一类。

extension WorldStore {
    // MARK: - 提示词上下文

    /// 交给 PromptBuilder 的只读快照。这里不拼提示词，业务层不写文案。
    ///
    /// `focus` 是这一轮用户说的话，只用来给记忆排序：跟当下话题沾边的事实排前面，
    /// 不然十几条按时间排，聊到猫的时候它已经被挤出去了。
    func context(
        for names: [String],
        deviceLines: [String],
        calendarLines: [String] = [],
        focus: String = "",
        listeningNow: Track? = nil,
        now: Date = Date()
    ) -> WorldContext {
        let keys = Set(names)
        let people = state.people.filter { keys.contains($0.name) }

        // 单聊时把他所在那几个群的记录也一起读出来。
        //
        // 群聊要做三件事：他自己在群里那份记忆（`groupNotes`）、群里共同记下的
        // 事实（群名那条 `people`）、以及群里攒的摘要。少一样，「你上次在群里
        // 说的那句」就接不住。但心事不跨群——那是别人私下的东西，不该漏给他。
        //
        // 群聊本身不用做这一步：那时群就在 `names` 里。
        let owner = names.first ?? ""
        let isGroupChat = state.groups[owner] != nil
        let groupNames = isGroupChat ? [] : state.groupsInvolving(owner)
        let groupKeys = Set(groupNames)
        let groupPeople = state.people.filter { groupKeys.contains($0.name) }

        // 群聊只读群名下记的事。
        //
        // 每个人的私聊事实全读进来，等于把几个人跟用户说过的私事摊在桌上；
        // 群里说话时状态块记下的那条也已经进了群名，够用了。
        let factPool = isGroupChat
            ? state.people.filter { $0.name == owner }.flatMap(\.facts)
            : people.flatMap(\.facts) + groupPeople.flatMap(\.facts)

        let facts = factPool
            .sorted { lhs, rhs in
                let left = Self.relevance(lhs.text, focus: focus)
                let right = Self.relevance(rhs.text, focus: focus)
                if left != right { return left > right }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(14)
            .map { $0 }

        // 每个人的记忆拼成一段。
        //
        // 群聊和单聊读的东西**不一样**，这一点很要紧：
        // 单聊时读他自己全部的记忆（一对一那份 + 各群里那份）；
        // 群聊时只读「这个群共同的记载」和「各人在这个群里做过什么」，
        // 不能把谁跟用户私聊过的内容摊到群里——那会变成当众念别人的私信。
        let summaries = people.compactMap { person -> String? in
            if isGroupChat {
                if person.name == owner {
                    let base = person.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    return base.isEmpty ? nil : "群里的记载：\n\(base)"
                }
                guard let note = person.groupNotes[owner], !note.isEmpty else { return nil }
                return "\(person.name)在群里：\n\(note)"
            }

            var parts: [String] = []
            let base = person.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty { parts.append(base) }
            for group in person.groupNotes.keys.sorted() {
                guard let note = person.groupNotes[group], !note.isEmpty else { continue }
                parts.append("在「\(group)」群里：\(note)")
            }
            guard !parts.isEmpty else { return nil }
            return "\(person.name)：\n" + parts.joined(separator: "\n")
        }

        // 群里大家共同的那一段也要读。各人那份只记了他自己的视角，
        // 「群里到底发生了什么事」在群名下那一条里。
        //
        // 截到 400 字：一个群上千字的摘要塞进一对一，会把当前对话挤没；
        // 他要的只是「知道有这么回事」的分寸。
        let groupDigests = isGroupChat ? [] : groupPeople.compactMap { group -> String? in
            let base = group.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !base.isEmpty else { return nil }
            return "「\(group.name)」这个群里：\n" + String(base.prefix(400))
        }

        let mergedSummaries = summaries + groupDigests

        // 群里只挑两条心事。
        //
        // 一群人有四条心事挂在提示词里，模型会当成「每个人都该有点内心戏」，
        // 聊着聊着整段就变成三个人各自的心理描写。两条足够点出气氛。
        let voices = people
            .flatMap(\.voices)
            .filter { !$0.isResolved }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(isGroupChat ? 2 : 4)
            .map { $0 }

        let usage = state.usage
            .sorted { $0.seconds > $1.seconds }
            .prefix(3)
            .map { "\($0.appName) \(Int($0.seconds / 60)) 分钟" }

        // 只取这次对话的对象自己的日子。群聊时说话人不止一个，
        // 硬塞所有人的日程会让模型分不清哪段经历是谁的。
        let days = state.characterDays
            .filter { $0.name == owner }
            .sorted { $0.dateKey > $1.dateKey }
            .prefix(4)
            .map { $0 }

        // 他自己发过的帖子。没有这一块，他会被问「你昨天发的那条是什么」然后答不上来。
        let social = state.feed
            .filter { $0.authorName == owner }
            .sorted { $0.postedAt > $1.postedAt }
            .prefix(3)
            .map { note -> String in
                var line = "- 「\(note.title)」，\(note.likes) 赞"
                if let first = note.comments.first {
                    line += "，\(first.authorName) 评论：「\(first.text)」"
                }
                return line
            }

        return WorldContext(
            summaries: mergedSummaries,
            facts: facts,
            voices: voices,
            mood: mood(for: owner),
            // 今天排了什么，排的是**他**的：我的日子在 `state.schedule` 里，
            // 拿我的安排去生成他的手机内容，会出现「他在打工我的工」。
            schedule: todaySchedule(for: owner),
            currentTrack: state.currentTrack,
            location: location(for: owner),
            deviceLines: deviceLines,
            usageLines: usage,
            days: days,
            userCalendarLines: calendarLines,
            socialLines: Array(social),
            phoneLines: phoneLines(for: owner),
            letterLines: letterLines(for: owner),
            listeningNow: listeningNow,
            // 走 `affinity(for:)` 而不是直接下标：没存过的时候它给 30，
            // 和状态面板上看到的是同一个数。直接取下标会拿到 nil，
            // 提示词里那一整块「你们现在的关系」就不出现，新人开局没有分寸。
            affinity: owner.isEmpty ? nil : affinity(for: owner),
            variables: state.variables
                .sorted { $0.key < $1.key }
                .prefix(12)
                .map { (key: $0.key, value: $0.value) },
            now: now
        )
    }
}

/// 提示词装配用的扁平视图，避免让 PromptBuilder 直接翻 WorldState 的内部结构。
struct WorldContext {
    var summaries: [String]
    var facts: [PersonFact]
    var voices: [InnerVoiceEntry]
    var mood: MoodState?
    var schedule: DaySchedule?
    var currentTrack: Track?
    var location: String
    var deviceLines: [String]
    var usageLines: [String]
    /// 这个角色自己这几天的日子，新的在前。
    var days: [CharacterDay] = []
    /// 用户系统日历里的安排。角色被允许读的时候才有值。
    var userCalendarLines: [String] = []
    /// 这个角色自己在西瓜皮上发过什么。发过的东西也要进记忆，否则问起会失忆。
    var socialLines: [String] = []
    /// 他自己手机里留过的东西：微信、相册、备忘录、购物车、搜索、时长、瞒着的事。
    var phoneLines: [String] = []
    /// 他写给你的信，只留标题和时间。信本身在信件里，不重复搬进提示词。
    var letterLines: [String] = []
    /// 这会儿真的在放的那首歌。暂停了不算——「在听」是个状态，不是历史。
    var listeningNow: Track?
    /// 这个角色的好感度。nil 表示还没建立，提示词里就不写这一段。
    var affinity: Int? = nil
    /// 自由变量表，已经排好序。整张表进提示词。
    var variables: [(key: String, value: String)] = []
    var now: Date
}
