import Foundation
import Observation

/// 世界状态文件的路径。放在类型外面，让备份层不必跨 actor 隔离取路径。
///
/// 跟着当前世界走：第一个世界还是 `Documents/world-state.json`，
/// 新建的世界在 `Documents/worlds/<id>/world-state.json`。
enum WorldStateFile {
    static var url: URL {
        WorldRegistry.stateURL(for: WorldRegistry.activeID)
    }
}

/// 世界状态的唯一读写入口。
///
/// 用单个 JSON 文件而不是 SwiftData：这份状态要被聊天、日历、音乐、
/// 健康等页面和提示词同时读写，一次写入对所有页面立刻可见；
/// 也避免给 SwiftData 增加一张需要版本化迁移的表。
@Observable
@MainActor
final class WorldStore {
    static let shared = WorldStore()

    /// 世界状态。
    ///
    /// 写入口只有 `WorldStore` 自己的方法（包括同模块下的 `+Refresh` 扩展）。
    /// setter 放开到 internal 是因为刷新流拆在另一个文件里，`private(set)`
    /// 在扩展里改不了；业务代码一律通过方法写，不要直接赋值。
    var state: WorldState
    /// 刚发生的刷新，界面弹一次就清掉。按页面记，用来配对应的图标。
    private(set) var pendingNotices: [RefreshPage] = []

    /// 刷新提示的写入入口。
    ///
    /// `pendingNotices` 的 setter 是 private，扩展在另一个文件里改不了，
    /// 所以留这一对方法给它用。
    func showNotices(_ pages: [RefreshPage]) {
        pendingNotices = pages
    }

    /// 界面上弹出过之后调用。
    func consumeNotice() {
        pendingNotices = []
    }
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? WorldStateFile.url
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let decoded = WorldStore.decode(data) {
            self.state = decoded
        } else {
            self.state = .empty
        }
    }

    /// 备份恢复后重新读盘。SwiftData 和世界状态是两套存储，必须分别刷新。
    func reload() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = WorldStore.decode(data) {
            state = decoded
        } else {
            state = .empty
        }
    }

    /// 写盘用 ISO8601，读盘必须用同一个策略。
    ///
    /// 这里之前读盘用的是默认解码器（自 2001 起的秒数），和写盘不一致，
    /// 导致每次启动都解不开、静默退回空状态——跨会话的记忆就是这样丢的。
    /// 两种策略都试一遍，是为了把不同版本写出来的存档都认下来。
    private static func decode(_ data: Data) -> WorldState? {
        let iso = JSONDecoder()
        iso.dateDecodingStrategy = .iso8601
        if let value = try? iso.decode(WorldState.self, from: data) {
            return value
        }
        return try? JSONDecoder().decode(WorldState.self, from: data)
    }

    // MARK: - 存取

    func save() {
        state.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 供备份恢复使用：整份替换，不合并，避免新旧数据互相覆盖。
    func replace(with snapshot: WorldState) {
        state = snapshot
        save()
    }

    // MARK: - 日程与心情

    /// 一天只生成一次。返回是否生成了新日程。
    @discardableResult
    func ensureToday(wakeHour: Int, sleepHour: Int, now: Date = Date()) -> Bool {
        let key = DayScheduleEngine.dateKey(now)
        guard state.schedule?.dateKey != key else { return false }

        state.schedule = DayScheduleEngine.generate(date: now, wakeHour: wakeHour, sleepHour: sleepHour)
        if let base = DayScheduleEngine.scheduledMood(schedule: state.schedule, now: now) {
            state.mood = MoodState(
                mood: base,
                reason: "按今天的日程",
                updatedAt: now,
                source: .schedule
            )
        }
        save()
        return true
    }

    // MARK: - 角色日历

    /// 读某个角色某一天的时间轴，没有就是没有。
    func characterDay(named name: String, on date: Date = Date()) -> CharacterDay? {
        let key = DayScheduleEngine.dateKey(date)
        return state.characterDays.first { $0.name == name && $0.dateKey == key }
    }

    /// 某个角色留下的全部日子，新的在前。
    func characterDays(named name: String, limit: Int = 30) -> [CharacterDay] {
        Array(
            state.characterDays
                .filter { $0.name == name }
                .sorted { $0.dateKey > $1.dateKey }
                .prefix(limit)
        )
    }

    /// 取某个角色某一天的时间轴，没有就现生成一份。
    ///
    /// 调用点只有两处：点开他的日历、以及当天第一次聊天。
    /// 不点不开就不生成——用户不会为二十个没聊过的人各付一份内容。
    ///
    /// 生成时会避开前一天做过的事，否则连续两天都是「去楼下买咖啡」，
    /// 一眼就能看出是模板在转。
    @discardableResult
    func ensureCharacterDay(
        named name: String,
        on date: Date = Date(),
        wakeHour: Int = 7,
        sleepHour: Int = 23,
        replies: Int = 0
    ) -> CharacterDay {
        if let existing = characterDay(named: name, on: date) {
            return existing
        }

        let calendar = Calendar.current
        let yesterdayKey = calendar
            .date(byAdding: .day, value: -1, to: date)
            .map { DayScheduleEngine.dateKey($0) }
        let yesterdayTitles = Set(
            state.characterDays
                .first { $0.name == name && $0.dateKey == yesterdayKey }?
                .items.map(\.title) ?? []
        )

        let day = DayScheduleEngine.generateCharacterDay(
            name: name,
            date: date,
            wakeHour: wakeHour,
            sleepHour: sleepHour,
            stage: .of(replies: replies),
            avoiding: yesterdayTitles
        )

        state.characterDays.append(day)
        pruneCharacterDays()
        save()
        return day
    }

    /// 聊过之后在当天那份上盖一个章，并把这次聊天的概括写进去。
    ///
    /// 概况不覆盖已有的：同一天聊三次，前两次的内容也要留着，
    /// 否则他只能记住最后一次说了什么。
    func noteCharacterChat(named name: String, summary: String, on date: Date = Date()) {
        guard let index = state.characterDays.firstIndex(where: {
            $0.name == name && $0.dateKey == DayScheduleEngine.dateKey(date)
        }) else { return }

        state.characterDays[index].didChat = true
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            save()
            return
        }

        let existing = state.characterDays[index].summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            state.characterDays[index].summary = trimmed
        } else if !existing.contains(trimmed) {
            state.characterDays[index].summary = existing + "；" + trimmed
        }
        save()
    }

    /// 只留最近 30 天。再往前的东西模型读不过来，留着只是让文件变大。
    private func pruneCharacterDays() {
        let cutoff = Calendar.current
            .date(byAdding: .day, value: -30, to: Date())
            .map { DayScheduleEngine.dateKey($0) } ?? "0000-00-00"
        state.characterDays.removeAll { $0.dateKey < cutoff }
    }

    /// 事件开始时把心情拉回日程基准；聊天带来的转折不受此影响。
    func refreshMoodFromSchedule(now: Date = Date()) {
        guard let base = DayScheduleEngine.scheduledMood(schedule: state.schedule, now: now) else { return }
        _ = updateMood(base, reason: "日程进入下一段", source: .schedule, at: now)
    }

    @discardableResult
    func updateMood(
        _ mood: Mood,
        reason: String,
        source: MoodSource,
        at: Date = Date()
    ) -> Bool {
        guard DayScheduleEngine.shouldUpdateMood(
            current: state.mood,
            to: mood,
            reason: reason,
            at: at,
            source: source
        ) else { return false }

        state.mood = MoodState(mood: mood, reason: reason, updatedAt: at, source: source)
        save()
        return true
    }

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

    // MARK: - 心声

    @discardableResult
    func appendVoice(person name: String, text: String, source: VoiceSource) -> UUID? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let index = state.ensurePerson(named: name)
        let entry = InnerVoiceEntry(
            id: UUID(),
            personName: name,
            text: clean,
            createdAt: Date(),
            source: source,
            isResolved: false,
            resolvedAt: nil,
            lastReferencedAt: nil
        )
        state.people[index].voices.append(entry)
        if state.people[index].voices.count > 80 {
            state.people[index].voices.removeFirst(state.people[index].voices.count - 80)
        }
        save()
        return entry.id
    }

    func resolveVoice(id: UUID) {
        for personIndex in state.people.indices {
            if let voiceIndex = state.people[personIndex].voices.firstIndex(where: { $0.id == id }) {
                state.people[personIndex].voices[voiceIndex].isResolved = true
                state.people[personIndex].voices[voiceIndex].resolvedAt = Date()
                save()
                return
            }
        }
    }

    func markReferenced(_ entries: [InnerVoiceEntry]) {
        let ids = Set(entries.map(\.id))
        for personIndex in state.people.indices {
            for voiceIndex in state.people[personIndex].voices.indices {
                if ids.contains(state.people[personIndex].voices[voiceIndex].id) {
                    state.people[personIndex].voices[voiceIndex].lastReferencedAt = Date()
                }
            }
        }
        save()
    }

    // MARK: - 音乐与使用记录

    func setCurrentTrack(_ track: Track?) {
        state.currentTrack = track
        save()
    }

    func noteUsage(appName: String, seconds: TimeInterval) {
        guard seconds > 0 else { return }
        if let index = state.usage.firstIndex(where: { $0.appName == appName }) {
            state.usage[index].seconds += seconds
            state.usage[index].lastOpenedAt = Date()
        } else {
            state.usage.append(
                AppUsageRecord(appName: appName, seconds: seconds, lastOpenedAt: Date())
            )
        }
        save()
    }

    // MARK: - 场景页数据

    /// 第一次进入时铺一层静态内容，之后一直读同一份，不会每次打开都换。
    ///
    /// 只铺西瓜皮：这几条是路人发的，和聊天无关，用来让版面第一次打开就有东西看。
    /// 购物不铺——那一页的意义就是「从你跟谁聊了什么推出来的」，
    /// 预置几件凭空出现的商品反而把这件事讲反了。
    func seedSceneContentIfNeeded(now: Date = Date()) {
        guard state.feed.isEmpty else { return }

        let seeds: [(title: String, body: String, tag: String, likes: Int)] = [
            ("周末去了趟旧书店", "三楼靠窗那排全是八九十年代的画册，蹲了一个下午。", "旧书", 47),
            ("这个季节最好吃的东西", "楼下水果摊的橘子，皮很薄，剥开一手都是味。", "橘子", 159),
            ("通勤路上拍到的云", "一整天都不太顺，但抬头的时候还是停了两秒。", "云", 75)
        ]

        state.feed = seeds.enumerated().map { index, item in
            FeedNote(
                id: UUID(),
                authorName: ["阿绿", "小林", "南南"][index % 3],
                authorUID: nil,
                title: item.title,
                body: item.body,
                tag: item.tag,
                likes: item.likes,
                comments: [],
                postedAt: now.addingTimeInterval(-Double(index + 1) * 5_400),
                coverSeed: StableSeed.of(item.title)
            )
        }
        save()
    }


    // MARK: - 信件

    /// 收一封。同一个角色写过的信不合并——每封都是当时那一次写的。
    func appendLetter(from name: String, title: String, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        state.letters.insert(
            Letter(
                id: UUID(),
                fromName: name,
                title: cleanTitle.isEmpty ? "写给你的信" : String(cleanTitle.prefix(24)),
                body: String(cleanBody.prefix(1_200)),
                createdAt: Date(),
                isRead: false
            ),
            at: 0
        )

        if state.letters.count > 60 {
            state.letters.removeLast(state.letters.count - 60)
        }
        save()
    }

    func markLetterRead(_ id: UUID) {
        guard let index = state.letters.firstIndex(where: { $0.id == id }) else { return }
        guard !state.letters[index].isRead else { return }
        state.letters[index].isRead = true
        save()
    }

    /// 收藏 / 取消收藏。读不读和收不收藏是两件事，所以不联动。
    func toggleLetterFavorite(_ id: UUID) {
        guard let index = state.letters.firstIndex(where: { $0.id == id }) else { return }
        state.letters[index].isFavorite.toggle()
        save()
    }

    // MARK: - 提示词上下文

    /// 交给 PromptBuilder 的只读快照。这里不拼提示词，业务层不写文案。
    func context(
        for names: [String],
        deviceLines: [String],
        calendarLines: [String] = [],
        now: Date = Date()
    ) -> WorldContext {
        let keys = Set(names)
        let related = state.people.filter { keys.contains($0.name) }

        let facts = related
            .flatMap(\.facts)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { $0 }

        let summaries = related
            .map { "\($0.name)：\($0.summary)" }
            .filter { !$0.hasSuffix("：") }

        let voices = related
            .flatMap(\.voices)
            .filter { !$0.isResolved }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { $0 }

        let usage = state.usage
            .sorted { $0.seconds > $1.seconds }
            .prefix(3)
            .map { "\($0.appName) \(Int($0.seconds / 60)) 分钟" }

        // 只取这次对话的对象自己的日子。群聊时说话人不止一个，
        // 硬塞所有人的日程会让模型分不清哪段经历是谁的。
        let owner = names.first ?? ""
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
            summaries: summaries,
            facts: facts,
            voices: voices,
            mood: state.mood,
            schedule: state.schedule,
            currentTrack: state.currentTrack,
            location: state.location,
            deviceLines: deviceLines,
            usageLines: usage,
            days: days,
            userCalendarLines: calendarLines,
            socialLines: Array(social),
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
    var now: Date
}
