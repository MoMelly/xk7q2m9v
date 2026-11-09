import SwiftUI
import SwiftData
import UIKit

/// 聊天页里的「发出去」这一摊。
///
/// 表情、图片、红包、文字都走 `viewModel.send` 同一条链路，
/// 只是带的参数不同。单独放一个文件是为了让主视图回到 500 行以内——
/// 这些方法彼此之间没有调用关系，搬走不影响任何时序。
///
/// 需要读的是页面级状态（草稿、正在引用的那条、面板开关），
/// 所以这些都从 `private` 放开到模块内可见。
extension ChatView {
    // MARK: - 表情面板

    /// 表情也是消息：落成一条 `[表情:名字]`，跟打字发出去走同一条链路，
    /// 这样记忆、重试、导出都不用为它单独开一条路。
    func sendSticker(_ item: StickerItem) {
        guard !viewModel.isStreaming else { return }
        showStickers = false
        Task {
            await viewModel.send(
                "[表情:\(item.name)]",
                character: character,
                context: context,
                settings: settings
            )
        }
    }

    // MARK: - 发图面板

    /// 发一个红包。
    ///
    /// 落库的是两样东西：一张红包卡（界面画它），和一句人话（进提示词）。
    /// 只有卡的话模型看不见发生过什么；只有字的话聊天里没有能拆的东西。
    func sendPacket(cents: Int, note: String) {
        showPacket = false
        let amount = String(format: "%.2f", Double(cents) / 100)
        let text = note.isEmpty
            ? "给你发了个红包，\(amount) 元。"
            : "给你发了个红包，\(amount) 元，附言「\(note)」。"
        Task {
            await viewModel.send(
                text,
                character: character,
                context: context,
                settings: settings,
                packetCents: cents,
                packetNote: note
            )
        }
    }

    /// 拆红包。只改这一条消息的状态，不触发回复。
    func openPacket(_ message: StoredMessage) {
        guard message.packetCents > 0, !message.packetOpened else { return }
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.18)) {
            message.packetOpened = true
        }
        try? context.save()
    }

    func sendPhoto(_ subject: MockPhotoSubject) {
        guard !viewModel.isStreaming else { return }
        showPhotos = false
        isInputFocused = false
        Task {
            await viewModel.send(
                subject.title,
                character: character,
                context: context,
                settings: settings,
                imageSeed: subject.seed
            )
        }
    }

    func submit() {
        guard canSend else { return }
        let text = draft
        draft = ""

        // 编辑态下发送 = 覆写那一条，不新起一条。
        if let target = editingTarget {
            target.text = text
            target.editedAt = Date()
            editingTarget = nil
            try? context.save()
            return
        }

        let quoted = quoting
        quoting = nil

        Task {
            await viewModel.send(
                text,
                character: character,
                context: context,
                settings: settings,
                quoteSpeaker: quoted.map { $0.role == .user ? "我" : character.name } ?? "",
                quoteText: quoted?.text ?? ""
            )
        }
    }
}
