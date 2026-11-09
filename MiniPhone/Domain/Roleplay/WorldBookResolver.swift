import Foundation

/// 世界书解析：决定这一轮把哪几条设定送进提示词，以及送到哪个位置。
///
/// 从 `PromptBuilder` 里拆出来是因为判断逻辑开始有分支了——三条触发路径、
/// 四个条件维度、优先级和位置。混在拼字符串的代码里，改一条规则要读完整段模板。
enum WorldBookResolver {
    /// 一轮的解析结果。按插入位置分成两组，各自已经排好序。
    struct Resolved {
        var front: [String] = []
        var back: [String] = []

        var isEmpty: Bool { front.isEmpty && back.isEmpty }
        var count: Int { front.count + back.count }
    }

    /// 一次解析需要的全部状态。传值而不是传 `WorldContext`：
    /// 这里只关心「判断条件用得上的那几个」，带整个 context 会让测试和预览都得造一整套。
    struct Conditions {
        var hour: Int
        var mood: Mood?
        var location: String
        var knownDays: Int

        static func build(hour: Int, mood: Mood?, location: String, since joined: Date, now: Date) -> Conditions {
            Conditions(hour: hour, mood: mood, location: location,
                       knownDays: Self.daysBetween(joined, and: now))
        }

        static func daysBetween(_ from: Date, and to: Date) -> Int {
            let cal = CharacterClock.calendar
            let start = cal.startOfDay(for: from)
            let end = cal.startOfDay(for: to)
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
            return max(0, days)
        }
    }

    /// 单组上限。再多就开始挤对话本身，模型也会照着念设定。
    private static let frontLimit = 8
    private static let backLimit = 6

    static func resolve(
        entries: [WorldEntry],
        character: Companion,
        triggerText: String,
        conditions: Conditions
    ) -> Resolved {
        let haystack = triggerText.lowercased()

        let picked = entries.filter { entry in
            isEligible(entry, character: character)
                && matches(entry, haystack: haystack, conditions: conditions)
        }

        // 排序：优先级高的先出现；同级时全局条目在前（世界观立住，细节再补），
        // 再按建立时间，最后用 uid 兜底保证顺序稳定——SwiftData 的取回顺序不保证。
        let sorted = picked.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.uid.uuidString < rhs.uid.uuidString
        }

        var result = Resolved()
        for entry in sorted {
            let text = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            switch entry.position {
            case .front: result.front.append(text)
            case .back: result.back.append(text)
            }
        }

        result.front = Array(result.front.prefix(frontLimit))
        result.back = Array(result.back.prefix(backLimit))
        return result
    }

    // MARK: - 逐条判断

    /// 这条能不能参与本次匹配：开着的、且属于当前角色或全局。
    private static func isEligible(_ entry: WorldEntry, character: Companion) -> Bool {
        guard entry.enabled else { return false }
        guard let owner = entry.characterUID else { return true }
        return owner == character.uid
    }

    private static func matches(_ entry: WorldEntry, haystack: String, conditions: Conditions) -> Bool {
        switch entry.kind {
        case .constant:
            return true

        case .condition:
            // 没写条件的条件条目按常驻处理：存成「永远不命中」是最难排查的一种坏状态。
            guard entry.hasCondition else { return true }
            return conditionsMatch(entry, conditions: conditions)

        case .keyword:
            guard !haystack.isEmpty else { return false }
            let keywords = entry.keywordList
            guard !keywords.isEmpty else { return false }
            return keywords.contains { haystack.contains($0.lowercased()) }
        }
    }

    private static func conditionsMatch(_ entry: WorldEntry, conditions: Conditions) -> Bool {
        let phases = entry.phaseList
        if !phases.isEmpty, !phases.contains(where: { $0.contains(hour: conditions.hour) }) {
            return false
        }

        let moods = entry.moodList
        if !moods.isEmpty {
            guard let current = conditions.mood, moods.contains(current) else { return false }
        }

        let needle = entry.locationNeedle
        if !needle.isEmpty {
            guard conditions.location.localizedCaseInsensitiveContains(needle) else { return false }
        }

        if entry.condMinDays > 0, conditions.knownDays < entry.condMinDays {
            return false
        }

        return true
    }
}
