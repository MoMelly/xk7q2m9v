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

    /// 角色用的另一套模板。
    ///
    /// 上面那套是「我的」工作日节奏，拿来给所有角色会每个人都在开例会。
    /// 这套偏生活向，配合各自的作息时间，看起来才不像同一个人的分身。
    private static let characterPool: [Template] = [
        Template(title: "赖床到中午", mood: .calm, note: "醒了又睡回去"),
        Template(title: "去楼下买咖啡", mood: .glad, note: "今天豆子换了"),
        Template(title: "写点东西", mood: .focused, note: "写了两小时删了一大半"),
        Template(title: "练一会儿琴", mood: .glad, note: "手指有点生"),
        Template(title: "整理房间", mood: .calm, note: "把书重新排了一遍"),
        Template(title: "出门散步", mood: .calm, note: "绕了很远的一段路"),
        Template(title: "看了一部老片子", mood: .glad, note: "看到一半睡着了"),
        Template(title: "被临时叫出去", mood: .annoyed, note: "原本想在家待着"),
        Template(title: "在窗边发呆", mood: .low, note: "说不上来为什么"),
        Template(title: "做完一件拖了很久的事", mood: .excited, note: "终于交了"),
        Template(title: "去超市", mood: .calm, note: "买了一堆不必要的东西"),
        Template(title: "很早就睡了", mood: .tired, note: "一整天都提不起劲")
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

    /// 某个角色某一天的时间轴。
    ///
    /// 种子由「名字 + 日期」组成，所以同一天同一个人永远生成同一份，
    /// 不同人之间又互不相同。`wakeHour` / `sleepHour` 来自角色自己的作息，
    /// 夜猫子角色不会出现上午九点的安排。
    static func generateCharacterDay(
        name: String,
        date: Date = Date(),
        wakeHour: Int = 7,
        sleepHour: Int = 23,
        stage: RelationshipStage = .familiar,
        avoiding: Set<String> = []
    ) -> CharacterDay {
        let key = dateKey(date)
        var generator = seed(name + "|" + key)

        func next() -> UInt64 {
            generator ^= generator << 13
            generator ^= generator >> 7
            generator ^= generator << 17
            return generator
        }

        let pool: [Template]
        switch stage {
        case .distant: pool = distantPool
        case .familiar: pool = characterPool
        case .close: pool = closePool
        }

        // 前一天做过的先排除，池子不够用再放回来。
        // 不加这一条，隔天撞同一件事的概率高得肉眼可见。
        let preferred = pool.filter { !avoiding.contains($0.title) }
        let candidates = preferred.count >= 4 ? preferred : pool

        let hours = [10, 13, 16, 20, 22].filter { $0 > wakeHour && $0 < sleepHour }
        var used = Set<String>()
        let items: [ScheduleItem] = hours.map { hour in
            // 同一天里也不重复：同一个人不会一天里两次「去楼下买咖啡」。
            let rest = candidates.filter { !used.contains($0.title) }
            let source = rest.isEmpty ? candidates : rest
            let template = source[Int(next() % UInt64(source.count))]
            used.insert(template.title)
            return ScheduleItem(
                id: UUID(),
                hour: hour,
                title: template.title,
                mood: template.mood,
                note: template.note
            )
        }

        // 一天的主心情取出现次数最多的那种；平手时取更晚发生的，读起来更像「后来心情变了」。
        var tally: [Mood: Int] = [:]
        for item in items {
            tally[item.mood, default: 0] += 1
        }
        let dominant = items
            .map(\.mood)
            .max { left, right in
                let leftCount = tally[left] ?? 0
                let rightCount = tally[right] ?? 0
                if leftCount == rightCount {
                    let leftHour = items.last { $0.mood == left }?.hour ?? 0
                    let rightHour = items.last { $0.mood == right }?.hour ?? 0
                    return leftHour < rightHour
                }
                return leftCount < rightCount
            } ?? .calm

        return CharacterDay(
            name: name,
            dateKey: key,
            items: items,
            mood: dominant,
            generatedAt: date
        )
    }

    /// 关系阶段。
    ///
    /// 不用新增字段来表示：回复次数本身就是关系在推进的证据，
    /// 而且它不需要模型配合，也不会因为一次误判就把关系退回陌生。
    enum RelationshipStage: String, Codable {
        case distant
        case familiar
        case close

        static func of(replies: Int) -> RelationshipStage {
            if replies >= 60 { return .close }
            if replies >= 20 { return .familiar }
            return .distant
        }

        var label: String {
            switch self {
            case .distant: return "还不熟"
            case .familiar: return "聊得来了"
            case .close: return "很熟"
            }
        }
    }

    /// 还不熟的时候，一天的主线基本是独处，也少有情绪外露。
    private static let distantPool: [Template] = [
        Template(title: "睡了很久", mood: .tired, note: "醒来已经过了中午"),
        Template(title: "去店里待了一天", mood: .calm, note: "没什么客人"),
        Template(title: "一个人吃了晚饭", mood: .calm, note: "很快吃完就走了"),
        Template(title: "在楼下站了一会儿", mood: .low, note: "不太想上楼"),
        Template(title: "翻了几页书", mood: .focused, note: "看不进去"),
        Template(title: "把该做的事做完了", mood: .focused, note: "没有再拖"),
        Template(title: "很早就关灯了", mood: .tired, note: "但没睡着")
    ]

    /// 关系近了之后，日程里会开始出现「留着时间」这件事。
    private static let closePool: [Template] = [
        Template(title: "留了一下午没安排", mood: .glad, note: "想着你可能会来找我说点什么"),
        Template(title: "看到一样觉得你会喜欢的东西", mood: .excited, note: "差点直接买下来"),
        Template(title: "把你说过的那部片子看了", mood: .calm, note: "看到一半想跟你讲"),
        Template(title: "在等你先开口", mood: .calm, note: "消息框点开又关掉"),
        Template(title: "睡过头了", mood: .tired, note: "梦见在跟你说话"),
        Template(title: "做了一桌吃不完的菜", mood: .glad, note: "有点想让你也尝尝"),
        Template(title: "把房间收拾干净了", mood: .focused, note: "顺手换了床单"),
        Template(title: "忽然有点低落", mood: .low, note: "说不上来，可能是天气")
    ]

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
