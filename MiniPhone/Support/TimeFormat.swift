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
    private static let lockDateFormatter = make("M月d日 EEEE")
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
}
