import SwiftUI

/// 一起听的状态条。
///
/// 邀请之后在对话上方留一条：和谁、在放什么、怎么散。
/// 没有这一条，邀请就变成了一个点完看不出结果的动作——
/// 歌在自己耳朵里，界面上没有任何变化。
struct ChatTogetherBar: View {
    let partnerName: String
    /// 这台手机上有没有一首歌（暂停也算）。没有就是还没开始听。
    let trackTitle: String?
    let isPlaying: Bool

    var onEnd: () -> Void

    private var text: String {
        guard let trackTitle, !trackTitle.isEmpty else {
            return "和\(partnerName)一起听 · 去音乐里放一首"
        }
        if isPlaying {
            return "和\(partnerName)一起在听 · \(trackTitle)"
        }
        return "和\(partnerName)一起听 · 暂停中"
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "headphones")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mint.opacity(0.9))

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.cream.opacity(0.78))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                onEnd()
            } label: {
                Text("结束")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.cream.opacity(0.42))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 3)
        .background(Theme.cream.opacity(0.06))
    }
}
