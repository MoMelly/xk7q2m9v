import Foundation
import Observation

/// 手动刷新的结果。
///
/// 单独一个类型是为了让界面只说一句话：要么「更新了几条」，要么「为什么没更新」。
/// 把错误吞成 0 条会让用户以为按钮坏了。
enum RefreshOutcome {
    case added(Int)
    case empty
    case failed(String)

    var text: String {
        switch self {
        case .added(let count): return "刚刚更新了 \(count) 条"
        case .empty: return "这次没刷出新内容，再点一次"
        case .failed(let reason): return reason
        }
    }

    var isSuccess: Bool {
        if case .added = self { return true }
        return false
    }
}

/// 页面刷新。
///
/// 自动刷新挂在聊天上（一次回复顺手带两三条），这里管的是另一种：
/// 用户在页面上点刷新图标，一次请求只要内容，八条一起回来。
/// 两条路最后都写进同一个 `WorldStore`，页面上分不出是哪条路来的。
@Observable
@MainActor
final class RefreshService {
    static let shared = RefreshService()

    /// 正在刷的页面。按钮据此转圈并禁用，同一页不会叠两次请求。
    private(set) var running: Set<RefreshPage> = []

    func isRefreshing(_ page: RefreshPage) -> Bool {
        running.contains(page)
    }

    @discardableResult
    func refresh(_ page: RefreshPage, settings: SettingsStore) async -> RefreshOutcome {
        guard !running.contains(page) else { return .empty }
        guard settings.isConfigured else {
            return .failed("还没填 API Key。点桌面上的设置填一个。")
        }

        running.insert(page)
        defer { running.remove(page) }

        let world = WorldStore.shared
        let state = world.state
        let titles = state.feed
            .sorted { $0.postedAt > $1.postedAt }
            .prefix(8)
            .map(\.title)

        let prompt = PromptBuilder.pageRefreshPrompt(
            page: page,
            state: state,
            // 西瓜皮和购物是我自己看的页面，这里写的是「最近那个人的状态」，
            // 只是给内容定个调子，不是说我本人现在这样。
            mood: world.mood(for: world.primaryName),
            location: world.location(for: world.primaryName),
            schedule: world.todaySchedule(for: world.primaryName),
            existingTitles: Array(titles)
        )

        let client = OpenAICompatibleClient(config: settings.config)

        do {
            let raw = try await client.complete([
                ChatMessage(role: .system, text: PromptBuilder.pageRefreshSystem),
                ChatMessage(role: .user, text: prompt)
            ])

            let envelope = ReplyEnvelope.parse(raw)
            RawReplyLog.shared.append(
                characterName: "刷新 · \(page.title)",
                model: settings.model,
                raw: raw,
                envelope: envelope
            )

            guard let meta = envelope.meta else {
                return .failed("模型这次写的内容解析不了，原始回复在设置里能看到。")
            }

            var added = 0
            switch page {
            case .feed:
                added = world.applyFeedDrafts(
                    meta.feed ?? [],
                    author: "网友",
                    authorUID: nil,
                    limit: 8
                )
                added += world.applyFeedComments(meta.feedComments ?? [], limit: 3)
            case .shop:
                added = world.applyShopDrafts(meta.shop ?? [], limit: 8)
            }

            guard added > 0 else {
                return .empty
            }

            world.markRefreshed([page])
            return .added(added)
        } catch {
            AppLog.ui.error("手动刷新失败: \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }
}
