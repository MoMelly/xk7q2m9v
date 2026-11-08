import Foundation

/// 情侣空间的数据。
///
/// 两侧各记一份「哪天说过话」，火花算的是交集。存一份合并后的日期不够用：
/// 一个人连着说十天，另一个人十天没开口，那不该有火花。
///
/// 连续天数不存，现算。存计数早晚会和日期集合对不上，改一次就再也算不回来。
struct CoupleState: Codable, Equatable {
    /// 我说过话的日期键（yyyy-MM-dd）。
    var myDays: [String] = []
    /// 他说过话的日期键。
    var theirDays: [String] = []
    /// 这段关系从哪天开始。第一次双向互动那天写一次，之后不再动。
    var sinceKey: String?
}

extension CoupleState {
    /// 两个人都开过口的那些天，升序。
    var activeDays: [String] {
        let their = Set(theirDays)
        return myDays.filter { their.contains($0) }.sorted()
    }
}

/// 火花的算法。
///
/// 「说过话」的判定在调用方（消息落地时），这里只负责记和算。
enum CoupleEngine {
    /// 记下今天我开过口。重复调用不会写两条。
    static func markMine(_ state: inout CoupleState, day: String = DayScheduleEngine.dateKey()) {
        insert(day, into: &state.myDays)
        stampSince(&state, day: day)
    }

    /// 记下今天他开过口。
    static func markTheirs(_ state: inout CoupleState, day: String = DayScheduleEngine.dateKey()) {
        insert(day, into: &state.theirDays)
        stampSince(&state, day: day)
    }

    /// 连续到今天几天。
    ///
    /// 今天还没双向时不算断——一天没结束，从昨天往前数，界面上写「今天还没续」。
    /// 只有昨天也没有，才算断了。
    static func streak(_ state: CoupleState, today: Date = Date()) -> Int {
        let calendar = Calendar.current
        let active = Set(state.activeDays)

        var cursor = calendar.startOfDay(for: today)
        if !active.contains(DayScheduleEngine.dateKey(cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while active.contains(DayScheduleEngine.dateKey(cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// 历史最长，用来在断了之后说「之前最长多少天」。
    static func best(_ state: CoupleState) -> Int {
        let calendar = Calendar.current
        let sorted = state.activeDays.compactMap { TimeFormat.date(fromKey: $0) }.sorted()

        var longest = 0
        var run = 0
        var previous: Date?

        for day in sorted {
            if let last = previous, calendar.dateComponents([.day], from: last, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = day
        }
        return longest
    }

    /// 今天算不算已经续上。
    static func isActiveToday(_ state: CoupleState, today: Date = Date()) -> Bool {
        state.activeDays.contains(DayScheduleEngine.dateKey(today))
    }

    /// 今天我一个人说话了、他还没开口。
    static func onlyMineToday(_ state: CoupleState, today: Date = Date()) -> Bool {
        let key = DayScheduleEngine.dateKey(today)
        return state.myDays.contains(key) && !state.theirDays.contains(key)
    }

    /// 最近 N 天，每天有没有双向。给热力图用，从早到晚。
    static func recent(_ state: CoupleState, days: Int, today: Date = Date()) -> [(key: String, active: Bool)] {
        let calendar = Calendar.current
        let active = Set(state.activeDays)
        let start = calendar.startOfDay(for: today)

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let key = DayScheduleEngine.dateKey(day)
            return (key, active.contains(key))
        }
    }

    private static func insert(_ day: String, into list: inout [String]) {
        guard !list.contains(day) else { return }
        list.append(day)
        list.sort()
    }

    /// 关系从哪天开始：第一次有互动那天。只有自己说过话也算起算点。
    private static func stampSince(_ state: inout CoupleState, day: String) {
        if state.sinceKey == nil || day < (state.sinceKey ?? day) {
            state.sinceKey = day
        }
    }
}
