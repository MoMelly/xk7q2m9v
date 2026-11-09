import Foundation
import Observation

/// 西瓜皮配图：按开关、按需、一张一张地生成。
///
/// 三件事决定了这一层为什么不能更「智能」：
/// 生图是按张收费的，一张几分钱，自动补全整屏就是十几张；
/// 生成一次要几秒到十几秒，用户可能根本还没滑到那一条；
/// 失败了重试没有尽头（额度、内容审核），得有个地方记住它别一直撞。
///
/// 所以：开关默认关 → 一次最多补两张 → 同一条失败过就不再自动试，
/// 想再试就自己点「换一张」。
@Observable
@MainActor
final class FeedImageService {
    static let shared = FeedImageService()

    /// 正在生成的帖子。卡片上用它显示「画着」的占位。
    private(set) var busyIDs: Set<UUID> = []
    /// 最近一次失败的原因，只在设置页和详情页露一行，不当弹窗。
    private(set) var lastError: String?
    /// 这一轮已经撞过墙的帖子。退出 App 就清空，不做持久化。
    private var givenUp: Set<UUID> = []

    private init() {}

    func isBusy(_ id: UUID) -> Bool { busyIDs.contains(id) }

    /// 进西瓜皮时调。只补最近的、没图的那几条，`limit` 卡住花费。
    func fillMissing(settings: SettingsStore, limit: Int = 2) async {
        guard settings.feedImages, settings.isConfigured else { return }
        let feed = WorldStore.shared.state.feed
            .sorted { $0.postedAt > $1.postedAt }
        var budget = limit
        for note in feed where note.imageFile == nil {
            guard budget > 0 else { break }
            guard !busyIDs.contains(note.id), !givenUp.contains(note.id) else { continue }
            budget -= 1
            _ = await generate(note: note, settings: settings)
        }
    }

    /// 手动「换一张」。忽略「失败过就不再试」那条，用户点一次就再试一次。
    @discardableResult
    func regenerate(noteID: UUID, settings: SettingsStore) async -> Bool {
        guard settings.isConfigured else {
            lastError = LLMError.missingKey.localizedDescription
            return false
        }
        guard let note = WorldStore.shared.state.feed.first(where: { $0.id == noteID }) else {
            return false
        }
        givenUp.remove(noteID)
        return await generate(note: note, settings: settings, force: true)
    }

    private func generate(note: FeedNote, settings: SettingsStore, force: Bool = false) async -> Bool {
        guard !busyIDs.contains(note.id) else { return false }
        if !force, note.imageFile != nil { return true }

        busyIDs.insert(note.id)
        defer { busyIDs.remove(note.id) }

        let client = ImageGenClient(config: settings.config, model: settings.imageModel)
        do {
            let prompt = PromptBuilder.feedImagePrompt(
                title: note.title,
                body: note.body,
                tag: note.tag
            )
            let image = try await client.generate(prompt: prompt)
            let fileName = try FeedImageStorage.save(image)
            FeedImageStorage.delete(note.imageFile)
            WorldStore.shared.setFeedImage(noteID: note.id, fileName: fileName)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            givenUp.insert(note.id)
            AppLog.ui.error("配图生成失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
