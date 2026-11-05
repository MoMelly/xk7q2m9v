import EventKit
import Foundation

/// 读用户 iOS 原生日历。
///
/// 只读、只取今天和明天、只取最靠前的几条。角色不需要看完整日程表，
/// 他只要知道「你今天下午三点有个会」就够开口关心了。
///
/// 权限拿不到就返回空数组，不抛错、不提示——关掉开关的角色本来就不该看到，
/// 这里再弹一次框会让人觉得被反复索要。
enum UserCalendarBridge {
    private static let store = EKEventStore()

    enum Access: Equatable {
        case unknown
        case denied
        case granted
    }

    static var status: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return .granted
        case .denied, .restricted, .writeOnly:
            return .denied
        default:
            return .unknown
        }
    }

    /// 申请完整读取权限。只在用户主动打开开关时调用。
    static func requestAccess() async -> Bool {
        if status == .granted { return true }
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            AppLog.ui.error("日历授权失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 今天和明天最靠前的几条安排，已经排成提示词里的一行一句。
    static func upcomingLines(limit: Int = 5) -> [String] {
        guard status == .granted else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)

        return events.map { event in
            let day = calendar.isDateInToday(event.startDate) ? "今天" : "明天"
            let title = event.title.isEmpty ? "（没有标题）" : event.title
            if event.isAllDay {
                return "- \(day)全天：\(title)"
            }
            let time = TimeFormat.clock(event.startDate)
            return "- \(day) \(time)：\(title)"
        }
    }

    /// 一句话说明「他现在能看到什么」，给设置页的开关底部文字用。
    static func statusLine(for characterName: String) -> String {
        switch status {
        case .granted:
            return "\(characterName) 能看到你今天和明天最靠前的几条安排。"
        case .denied:
            return "系统里这个 App 的日历权限是关掉的，去「设置 → 小手机 → 日历」打开。"
        case .unknown:
            return "打开后会请求读取你系统日历的权限。只读，不会修改。"
        }
    }
}
