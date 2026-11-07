import SwiftUI

/// 聊天输入栏上方的两块横滑面板：表情、发图。
///
/// 从 ChatView 拆出来单纯是因为行数门禁；拆的切口顺着数据流走——
/// 面板只认「当前角色」和「选中了什么」两个入参，落库与触发回复全在宿主那边，
/// 这两个面板对 ChatViewModel 一无所知。

/// 表情面板。全集由角色的「能用哪些表情」开关过滤，空的给一句指引。
struct ChatStickerPanel: View {
    let character: Companion
    let onPick: (StickerItem) -> Void

    var body: some View {
        let items = StickerLibrary.shared.available(for: character)

        Group {
            if items.isEmpty {
                Text("还没有表情。去设置 → 表情里加一些。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cream.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            Button {
                                onPick(item)
                            } label: {
                                StickerView(item: item, size: 54)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(height: 78)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// 发图面板。八种现画的图。这里不接相册：能发的是「场景」不是真拍的照片，
/// 从一排缩略图里挑比翻相册快得多，也不会把手机里的照片带进对话。
struct ChatPhotoPanel: View {
    let onPick: (MockPhotoSubject) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MockPhotoSubject.allCases, id: \.rawValue) { subject in
                    Button {
                        onPick(subject)
                    } label: {
                        VStack(spacing: 5) {
                            MockPhoto(seed: subject.seed)
                                .frame(width: 66, height: 50)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: PhoneMetrics.Radius.cover,
                                        style: .continuous
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: PhoneMetrics.Radius.cover,
                                        style: .continuous
                                    )
                                    .strokeBorder(Theme.cream.opacity(0.12), lineWidth: 1)
                                }

                            Text(subject.title)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.cream.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 86)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
