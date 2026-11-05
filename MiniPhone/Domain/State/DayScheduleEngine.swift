import Foundation

/// 日程与心情的本地生成规则。
///
/// 全部离线、零 API 调用：同一天的日程由日期字符串做种子，一天只生成一次，
/// 重复打开不会变。心情有冷却和去重，避免「聊一句就换一个状态」。
enum DayScheduleEngine {
    /// 两次自动变更之间的最小间隔。手动改动不受限。
    static let moodCooldown: TimeInterval = 30 * 60

    private struct Template: Hashable {
        let title: String
        let mood: Mood
        let note: String
    }

    private static let pool: [Template] = [
        Template(title: "晨间例会", mood: .annoyed, note: "会开得比预想的长"),
        Template(title: "整理资料", mood: .focused, note: "没空看手机"),
        Template(title: "和同事吃午饭", mood: .calm, note: "聊了些无关紧要的事"),
        Template(title: "下午的排练", mood: .tired, note: "站了一整个下午"),
        Template(title: "赶一份稿子", mood: .annoyed, note: "改到第三版"),
        Template(title: "去便利店", mood: .calm, note: "顺路买了点东西"),
        Template(title: "和朋友喝咖啡", mood: .glad, note: "难得坐下来聊天"),
        Template(title: "看一集剧", mood: .glad, note: "终于有空躺着"),
        Template(title: "散步", mood: .calm, note: "绕了两圈才回去"),
        Template(title: "收拾房间", mood: .focused, note: "顺手翻出些旧东西"),
        Template(title: "复诊", mood: .low, note: "不太想去"),
        Template(title: "临时加班", mood: .tired, note: "到家已经很晚")
    ]

    static func dateKey(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// FNV-1a，稳定且不依赖随机种子，保证同一天多次生成结果一致。
    private static func seed(_ key: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 10_987_695_113_214_669_137
        }
        return hash
    }

    static func generate(date: Date = Date(), wakeHour: Int = 7, sleepHour: Int = 23) -> DaySchedule {
        let key = dateKey(date)
        var generator = seed(key)

        func next() -> UInt64 {
            generator ^= generator << 13
            generator ^= generator >> 7
            generator ^= generator << 17
            return generator
        }

        let hours = [9, 12, 15, 19, 22].filter { $0 > wakeHour && $0 < sleepHour }
        let items: [ScheduleItem] = hours.map { hour in
            let template = pool[Int(next() % UInt64(pool.count))]
            return ScheduleItem(
                id: UUID(),
                hour: hour,
                title: template.title,
                mood: template.mood,
                note: template.note
            )
        }

        return DaySchedule(dateKey: key, items: items, generatedAt: date)
    }

    /// 当前时段该有的基准心情：取最近一个已开始的日程项。
    static func scheduledMood(schedule: DaySchedule?, now: Date = Date()) -> Mood? {
        guard let schedule else { return nil }
        let hour = Calendar.current.component(.hour, from: now)
        return schedule.items
            .filter { $0.hour <= hour }
            .max(by: { $0.hour < $1.hour })?
            .mood
    }

    /// 是否允许改写心情。
    ///
    /// 三种情况一律拒绝：与当前相同、冷却期内、自动更新却没给出起因。
    /// 事件切换（日程基准）和用户主动改动可以穿透冷却。
    static func shouldUpdateMood(
        current: MoodState?,
        to mood: Mood,
        reason: String,
        at: Date = Date(),
        source: MoodSource
    ) -> Bool {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let current else { return true }
        guard current.mood != mood else { return false }
        if source == .manual { return true }
        return at.timeIntervalSince(current.updatedAt) >= moodCooldown
    }
}
