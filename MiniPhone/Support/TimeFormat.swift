import Foundation

/// 全 App 唯一的日期时间格式化入口。
///
/// `DateFormatter` 的构造开销远大于格式化本身，而列表每一行、每条消息分隔条
/// 都要格式化一次时间。之前四处各建一份、且每调用一次就 new 一个，
/// 滚动时属于白花的开销——这里集中缓存，格式也只在一处定义。
enum TimeFormat {
    private static let locale = Locale(identifier: "zh_CN")

    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    private static let clockFormatter = make("HH:mm")
    private static let lockDateFormatter = make("M月d日EEE")
    private static let fullFormatter = make("yyyy年M月d日 EEEE HH:mm")
    private static let monthDayTimeFormatter = make("M月d日 HH:mm")
    private static let shortDateFormatter = make("M/d")

    /// 22:31
    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    /// 11月4日 星期三
    static func lockDate(_ date: Date) -> String {
        lockDateFormatter.string(from: date)
    }

    /// 2026年11月4日 星期三 22:31
    static func full(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    /// 11月4日 22:31
    static func monthDayTime(_ date: Date) -> String {
        monthDayTimeFormatter.string(from: date)
    }

    /// 11/4
    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// 通话记录里的时间：今天 11:45 / 昨天 09:12 / 10月3日 21:30。
    ///
    /// 系统通话记录不显示年份，同一天也不重复写日期，这里跟上。
    static func callTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天 " + clock(date) }
        if calendar.isDateInYesterday(date) { return "昨天 " + clock(date) }
        return monthDayTime(date)
    }

    // MARK: - 日历用的短格式

    /// 世界状态里的日期键。用 POSIX 而不是中文 locale：
    /// 这里只做机器解析，不该受地区设置影响。
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 「2026-11-05」→ Date
    static func date(fromKey key: String) -> Date? {
        dateKeyFormatter.date(from: key)
    }

    /// 今天 / 昨天 / 前天 / 11/2
    ///
    /// 给角色写提示词和记忆页共用：说「昨天」才像人开口，
    /// 说「11 月 3 日」模型多半会把日期原样复述一遍。
    static func dayLabel(_ key: String, today: Date = Date()) -> String {
        guard let date = date(fromKey: key) else { return key }
        return dayLabel(date, today: today)
    }

    static func dayLabel(_ date: Date, today: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: today)
        ).day ?? 0

        switch days {
        case 0: return "今天"
        case 1: return "昨天"
        case 2: return "前天"
        default: return shortDate(date)
        }
    }

    private static let monthFormatter = make("M月")
    private static let yearFormatter = make("yyyy年")
    private static let weekdayNarrowFormatter = make("EEEEE")
    private static let dayNumberFormatter = make("d")

    /// 11月
    static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    /// 2026年
    static func year(_ date: Date) -> String {
        yearFormatter.string(from: date)
    }

    /// 一
    static func weekdayNarrow(_ date: Date) -> String {
        weekdayNarrowFormatter.string(from: date)
    }

    /// 5
    static func dayNumber(_ date: Date) -> String {
        dayNumberFormatter.string(from: date)
    }

    /// 农历月日，例如「九月廿七」。
    ///
    /// 只取月和日。干支年需要按春节换算，公历年直接推会在年初差一年，
    /// 宁可不显示也不显示错的。
    static func lunarMonthDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = locale

        let comps = calendar.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else { return "" }

        let months = ["正月", "二月", "三月", "四月", "五月", "六月",
                      "七月", "八月", "九月", "十月", "冬月", "腊月"]
        let monthText = months.indices.contains(month - 1) ? months[month - 1] : "\(month)月"
        return monthText + lunarDay(day)
    }

    private static func lunarDay(_ day: Int) -> String {
        let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        switch day {
        case 1...10: return "初" + numerals[day - 1]
        case 11...19: return "十" + numerals[day - 11]
        case 20: return "二十"
        case 21...29: return "廿" + numerals[day - 21]
        case 30: return "三十"
        default: return ""
        }
    }
}
