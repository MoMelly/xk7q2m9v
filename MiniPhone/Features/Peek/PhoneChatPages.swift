import SwiftUI

/// 微信。列表照系统样式：一行一个会话，头像、名字、最后一句、时间、未读数。
///
/// 这里是**他的**微信，所以对话里他发的话在右边（绿），别人发的话在左边。
/// 跟「信息」相反 —— 那个是我自己的手机，右边永远是我。
struct PhoneChatListPage: View {
    let phone: CharacterPhone
    let owner: String

    private var chats: [PhoneChat] {
        phone.chats.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.time > rhs.time
        }
    }

    var body: some View {
        AppPage(title: "微信", surface: .light) {
            ScrollView {
                GroupedSection("\(chats.count) 个会话") {
                    ForEach(chats) { chat in
                        NavigationLink {
                            PhoneChatThreadPage(chat: chat, owner: owner)
                        } label: {
                            row(chat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func row(_ chat: PhoneChat) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            avatar(chat.name, tint: Theme.IconTint.green)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(chat.name)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)
                    if !chat.relation.isEmpty {
                        Text(chat.relation)
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.groupedBackground))
                    }
                }

                Text(chat.preview.isEmpty ? "（没有内容）" : chat.preview)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 5) {
                Text(chat.time)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                if chat.unread > 0 {
                    Text("\(chat.unread)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Theme.IconTint.pink))
                }
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, 56)
        }
        .contentShape(Rectangle())
    }

    private func avatar(_ name: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.85))
            Text(String(name.prefix(1)))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
    }
}

/// 一段具体的对话。只读，不给输入框 —— 翻手机是看，不是聊。
struct PhoneChatThreadPage: View {
    let chat: PhoneChat
    let owner: String

    var body: some View {
        AppPage(title: chat.name, surface: .light) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xs) {
                    ForEach(Array(chat.lines.enumerated()), id: \.offset) { _, line in
                        bubble(line)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.m)
            }
        }
    }

    private func bubble(_ line: PhoneLine) -> some View {
        HStack {
            if line.fromMe { Spacer(minLength: 44) }

            VStack(alignment: line.fromMe ? .trailing : .leading, spacing: 3) {
                Text(line.text)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(line.fromMe ? Theme.IconTint.green.opacity(0.16) : AppSurface.light.rowSurface)
                    )

                if !line.time.isEmpty {
                    Text(line.time)
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
            }

            if !line.fromMe { Spacer(minLength: 44) }
        }
    }
}
