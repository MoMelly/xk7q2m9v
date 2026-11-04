import Foundation

/// 时间与作息。
///
/// 拟真感里最便宜的一块：角色的生物钟只要出现在提示词里，
/// 深夜回话就会自然变短、带困意，不需要额外训练或规则引擎。
enum CharacterClock {
    private static let locale = Locale(identifier: "zh_CN")

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        return cal
    }

    /// 是否处于睡眠区间。
    ///
    /// 区间是 `[sleepHour, 24) ∪ [0, wakeHour)`，所以 23 点睡、7 点起
    /// 和 1 点睡、9 点起都能用同一个判断，不需要为跨零点写特殊分支。
    static func isAsleep(_ character: Companion, at now: Date = Date()) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let sleep = max(0, min(23, character.sleepHour))
        let wake = max(0, min(23, character.wakeHour))

        if sleep == wake { return false }
        if sleep > wake {
            return hour >= sleep || hour < wake
        } else {
            return hour >= sleep && hour < wake
        }
    }

    /// 给界面用的一句话状态。
    static func statusPhrase(_ character: Companion, at now: Date = Date()) -> String {
        isAsleep(character, at: now) ? "睡着的" : "在的"
    }

    /// 给提示词用的时间上下文。
    static func promptContext(
        _ character: Companion,
        now: Date = Date(),
        lastMessageAt: Date?
    ) -> String {
        var lines: [String] = []
        lines.append("现在是\(fullDescription(now))。")

        if isAsleep(character, at: now) {
            lines.append("这个点你已经睡了（你通常 \(character.sleepHour) 点睡、\(character.wakeHour) 点起）。你还醒着是因为对方把你吵醒了，回复要带着刚被叫醒的迟钝和困意，句子短，别说太长。")
        } else {
            lines.append("这个点你是醒着的（你通常 \(character.sleepHour) 点睡、\(character.wakeHour) 点起）。")
        }

        if let last = lastMessageAt {
            let gap = now.timeIntervalSince(last)
            if gap > 60 * 60 * 24 * 3 {
                lines.append("你们上一次说话是 \(Int(gap / 86_400)) 天前了，隔了很久，语气里可以有距离感或意外。")
            } else if gap > 60 * 60 * 6 {
                lines.append("你们上一次说话是 \(Int(gap / 3_600)) 小时前。")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 格式化

    static func fullDescription(_ date: Date) -> String {
        TimeFormat.full(date)
    }

    static func clockText(_ date: Date) -> String {
        TimeFormat.clock(date)
    }

    /// 会话列表右侧的时间：今天显示时刻，昨天显示「昨天」，更早显示日期。
    static func listTimestamp(_ date: Date, now: Date = Date()) -> String {
        let cal = calendar
        if cal.isDateInToday(date) {
            return TimeFormat.clock(date)
        }
        if cal.isDateInYesterday(date) {
            return "昨天"
        }
        return TimeFormat.shortDate(date)
    }

    /// 聊天页的时间分隔条。
    static func separatorText(_ date: Date, now: Date = Date()) -> String {
        let cal = calendar
        if cal.isDateInToday(date) {
            return TimeFormat.clock(date)
        }
        if cal.isDateInYesterday(date) {
            return "昨天 " + TimeFormat.clock(date)
        }
        return TimeFormat.monthDayTime(date)
    }
}
