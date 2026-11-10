import SwiftUI

/// 语音输入那颗按钮。
///
/// 从 `ChatView` 里拆出来的：主文件已经顶到 600 行上限，再往里加东西
/// 先得减。这一块只依赖 `SpeechService` 和输入面板的几个开关，不碰消息数据，
/// 整块挪出来最省事。
extension ChatView {
    var micButton: some View {
        let listening = SpeechService.shared.isListening

        return Button {
            let speech = SpeechService.shared
            if speech.isListening {
                speech.stopListening()
            } else {
                showStickers = false
                showPhotos = false
                speech.startListening()
                isInputFocused = false
            }
        } label: {
            Image(systemName: listening ? "waveform" : "mic")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(listening ? Theme.IconTint.pink : Theme.cream.opacity(0.72))
                .frame(width: 30, height: 30)
                .symbolEffect(.variableColor.iterative, isActive: listening)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("说话输入")
    }
}
