import Foundation
import Observation

/// 世界状态文件的路径。放在类型外面，让备份层不必跨 actor 隔离取路径。
enum WorldStateFile {
    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("world-state.json")
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

    private(set) var state: WorldState
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? WorldStateFile.url
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(WorldState.self, from: data) {
            self.state = decoded
        } else {
            self.state = .empty
        }
    }

    /// 备份恢复后重新读盘。SwiftData 和世界状态是两套存储，必须分别刷新。
    func reload() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(WorldState.self, from: data) {
            state = decoded
        } else {
            state = .empty
        }
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
    func seedSceneContentIfNeeded(now: Date = Date()) {
        var changed = false
        if state.shopping.isEmpty {
            changed = true
            state.shopping = [
                ShoppingItem(id: UUID(), title: "便携保温杯", price: "¥129", status: "已送达",
                             orderedAt: now.addingTimeInterval(-86_400 * 2)),
                ShoppingItem(id: UUID(), title: "一本没读完的小说", price: "¥42", status: "运输中",
                             orderedAt: now.addingTimeInterval(-86_400)),
                ShoppingItem(id: UUID(), title: "耳机收纳盒", price: "¥39", status: "待付款",
                             orderedAt: now)
            ]
        }
        if state.forum.isEmpty {
            changed = true
            state.forum = [
                ForumPost(id: UUID(), author: "路人甲", title: "今晚的月亮", body: "拍糊了，但舍不得删。",
                          postedAt: now.addingTimeInterval(-3_600 * 5), replyCount: 12),
                ForumPost(id: UUID(), author: "楼下咖啡", title: "新到的豆子", body: "偏酸，喝不惯的人别点。",
                          postedAt: now.addingTimeInterval(-3_600 * 20), replyCount: 4)
            ]
        }
        if changed { save() }
    }

    // MARK: - 提示词上下文

    /// 交给 PromptBuilder 的只读快照。这里不拼提示词，业务层不写文案。
    func context(
        for names: [String],
        deviceLines: [String],
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
    var now: Date
}
