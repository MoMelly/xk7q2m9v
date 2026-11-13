import Foundation
import Observation

/// 世界状态文件的路径。放在类型外面，让备份层不必跨 actor 隔离取路径。
///
/// 跟着「当前世界 + 当前身份」走：
/// - 默认身份沿用老路径（第一个世界 `Documents/world-state.json`，
///   新世界 `Documents/worlds/<id>/world-state.json`），升级不用迁移；
/// - 其它身份各有自己的一份，落在 `Documents/identity-states/<世界>/<身份>/`。
///
/// 按文件分而不是逐个字段打身份标签：好感度、日程、火花、心情、变量、
/// 心事、群摘要全在这一份里，一处切开就全切开，也不会漏掉某张表。
enum WorldStateFile {
    /// 非默认身份那几份状态的根目录。备份按整个目录搬。
    static var identityRootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("identity-states", isDirectory: true)
    }

    static func url(for personaUID: String, worldID: String = WorldRegistry.activeID) -> URL {
        guard !personaUID.isEmpty else { return WorldRegistry.stateURL(for: worldID) }
        let folder = identityRootURL
            .appendingPathComponent(safeComponent(worldID), isDirectory: true)
            .appendingPathComponent(safeComponent(personaUID), isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("world-state.json")
    }

    /// 当前身份该读写哪一份。读 UserDefaults 而不是取 `IdentityScope.shared`，
    /// 是为了让备份层（不跑在主线程隔离里）也能安全拿到同一个值。
    static var url: URL {
        let uid = UserDefaults.standard.string(forKey: IdentityScope.storageKey) ?? ""
        return url(for: uid)
    }

    /// 身份 id 是 UUID，但目录名还是过一遍，别把斜杠、空格带进路径。
    private static func safeComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("_") })
        return cleaned.isEmpty ? "unnamed" : cleaned
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
    /// 主屏、锁屏这些「只有一块地方」的界面显示谁的状态。
    ///
    /// 这些地方没有角色上下文，只能挑一个人：取最近说过话的那个，
    /// 跟「TA 的手机」默认打开谁同一套规则。外壳启动时告诉它。
    var primaryName: String = ""
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
    /// 当前身份对应的那一份文件。切换身份时换路径，不重建 store。
    private var fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? WorldStateFile.url
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let decoded = WorldStore.decode(data) {
            self.state = decoded
        } else {
            self.state = .empty
        }
        observeIdentityChanges()
    }

    /// 换身份 = 换一份世界状态：改文件、重新读盘，再按新那份生成今天。
    ///
    /// 不合并、不拷贝，新身份看到的就是一份空状态。老身份那份原样留在盘上，
    /// 切回来再读回来。通知和主屏的 onChange 都会调到它，重复调用是幂等的
    /// （`ensureToday` 有 dateKey 守卫）。
    func reloadForActiveIdentity() {
        adoptActiveIdentityFile()
        reload()
        ensureToday(wakeHour: 7, sleepHour: 23)
    }

    /// 只换目标文件、不读盘。清空整台手机时要先把写入口指回默认身份再落盘。
    func adoptActiveIdentityFile() {
        fileURL = WorldStateFile.url
    }

    /// 新建、切换、删掉当前身份后回退，都由 `IdentityScope` 发同一条通知。
    /// 在这里统一接，比在每个切换入口各调一次不容易漏。
    private func observeIdentityChanges() {
        _ = NotificationCenter.default.addObserver(
            forName: .identityChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WorldStore.shared.reloadForActiveIdentity()
            }
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
    ///
    /// 这一份是**我的**日程（日历里的「我的」、主屏那块「今天」）。
    /// 角色的日子不在这里，走 `ensureCharacterDay`，各人各一份。
    @discardableResult
    func ensureToday(wakeHour: Int, sleepHour: Int, now: Date = Date()) -> Bool {
        let key = DayScheduleEngine.dateKey(now)
        guard state.schedule?.dateKey != key else { return false }

        state.schedule = DayScheduleEngine.generate(date: now, wakeHour: wakeHour, sleepHour: sleepHour)
        save()
        return true
    }

    // MARK: - 他的心情与位置

    /// 某个角色此刻的心情。没聊过、也没排过日程就是 nil。
    func mood(for name: String) -> MoodState? {
        state.moods[name]
    }

    /// 主屏、锁屏上要显示的那一份。这些地方没有角色上下文，只能挑一个人。
    var primaryMood: MoodState? { mood(for: primaryName) }

    /// 某个角色此刻在哪。没写过就是空串。
    func location(for name: String) -> String {
        state.locations[name] ?? ""
    }

    func setLocation(_ text: String, for name: String) {
        guard !name.isEmpty else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            state.locations.removeValue(forKey: name)
        } else {
            state.locations[name] = clean
        }
        save()
    }

    /// 他今天的时间轴，包成 `DaySchedule` 给提示词和组件用。
    ///
    /// 角色的日子本来存在 `characterDays` 里，这里只是换个形状读出来，
    /// 不再另外存一份——存两份迟早对不上。今天没生成过就是 nil。
    func todaySchedule(for name: String) -> DaySchedule? {
        guard !name.isEmpty, let day = characterDay(named: name) else { return nil }
        return DaySchedule(dateKey: day.dateKey, items: day.items, generatedAt: day.generatedAt)
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
        // 第一次排他的日子时顺手给个基准心情：不然在他开口之前，
        // 主屏和锁屏上那块一直是「还没定」，看着像没生成。
        if state.moods[name] == nil {
            state.moods[name] = MoodState(
                mood: day.mood,
                reason: "按他今天的安排",
                updatedAt: day.generatedAt,
                source: .schedule
            )
        }
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
    func refreshMoodFromSchedule(for name: String, now: Date = Date()) {
        guard let base = DayScheduleEngine.scheduledMood(schedule: todaySchedule(for: name), now: now) else {
            return
        }
        _ = updateMood(base, reason: "日程进入下一段", source: .schedule, for: name, at: now)
    }

    @discardableResult
    func updateMood(
        _ mood: Mood,
        reason: String,
        source: MoodSource,
        for name: String,
        at: Date = Date()
    ) -> Bool {
        guard !name.isEmpty else { return false }
        guard DayScheduleEngine.shouldUpdateMood(
            current: state.moods[name],
            to: mood,
            reason: reason,
            at: at,
            source: source
        ) else { return false }

        state.moods[name] = MoodState(mood: mood, reason: reason, updatedAt: at, source: source)
        save()
        return true
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
}
