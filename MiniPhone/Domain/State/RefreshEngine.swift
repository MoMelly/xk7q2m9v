import Foundation

/// 会「自己更新」的页面。
///
/// 每加一个这类页面，只要在 `allCases` 里补一个 case，设置页、计数、提示
/// 都会自动跟着走，不用再改三处。
enum RefreshPage: String, Codable, CaseIterable, Identifiable, Hashable {
    case shop
    case feed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shop: return "购物"
        case .feed: return "小红书"
        }
    }

    var symbol: String {
        switch self {
        case .shop: return "bag.fill"
        case .feed: return "book.closed.fill"
        }
    }

    /// 刷新之后给用户看的那句话，模拟「App 发来一条消息」。
    var notice: String {
        switch self {
        case .shop: return "购物 · 给你挑了几件新的"
        case .feed: return "小红书 · 有人发了新笔记"
        }
    }
}

/// 单个页面的刷新配置。
struct RefreshRule: Codable, Identifiable, Hashable {
    var page: RefreshPage
    var enabled: Bool
    /// 0...1。到了间隔轮次之后，按这个概率决定刷不刷。
    var probability: Double

    var id: String { page.rawValue }

    static let `default`: [RefreshRule] = [
        RefreshRule(page: .shop, enabled: true, probability: 0.2),
        RefreshRule(page: .feed, enabled: true, probability: 0.2)
    ]
}

/// 这一轮允许刷新哪些页面。
struct RefreshRequest: Hashable {
    var pages: Set<RefreshPage>
    /// 已经发过笔记、可以让人来补评论的条数（标题），空表示这轮不写评论。
    var commentTargets: [String]

    var shopLimit: Int { 4 }
    var feedLimit: Int { 2 }
    var commentLimit: Int { 2 }

    var wantsShop: Bool { pages.contains(.shop) }
    var wantsFeed: Bool { pages.contains(.feed) }

    var notices: [String] {
        pages.sorted { $0.rawValue < $1.rawValue }.map(\.notice)
    }
}

/// 刷新判定。
///
/// 规则：每个页面各自维护「距上次刷新过了几轮」，到间隔之后按各自概率掷骰子，
/// 掷中就刷，刷完计数归零。所以两个页面不会同步变，购物可能连着刷两次，
/// 小红书一次都没动——这本来就是「不同 App 有各自的节奏」。
///
/// 按次计费允许一轮同时刷多个页面（同一次请求，不额外花钱）；
/// 按量计费每轮只放一个页面进来，把多出来的 token 压到最小。
enum RefreshEngine {
    /// 判定这一轮的结果。`nil` 表示这轮什么都不刷。
    ///
    /// `roll` 由调用方给，方便用固定值做测试。
    static func request(
        plan: GenerationPlan,
        state: WorldState,
        rules: [RefreshRule],
        interval: Int,
        recentTitles: [String],
        roll: () -> Double
    ) -> RefreshRequest? {
        var due: [RefreshPage] = []

        for rule in rules where rule.enabled {
            let elapsed = state.refreshTurns[rule.page.rawValue] ?? 0
            guard elapsed >= interval else { continue }
            guard roll() < rule.probability else { continue }
            due.append(rule.page)
        }

        guard !due.isEmpty else { return nil }

        if plan.mode == .perToken, due.count > 1 {
            due = [due[Int(roll() * Double(due.count)) % due.count]]
        }

        let pages = Set(due)
        // 有旧笔记才让模型顺手补评论；一条都没有就只发新的。
        var targets: [String] = []
        if pages.contains(.feed), !recentTitles.isEmpty {
            targets = Array(recentTitles.prefix(3))
        }

        return RefreshRequest(pages: pages, commentTargets: targets)
    }
}
