import SwiftUI

/// 「联系人」那一格的微信式列表。
///
/// 原来是一排等高的玻璃卡，人一多只能靠搜索找。现在按首字母分节，
/// 右边挂一条索引：点字母直接滚到那节，跟系统通讯录一样。
/// 群聊也按名字进节，行内挂「群」标——单独开一节会让索引条少几个字母。
struct ContactDirectoryView: View {
    let characters: [Companion]
    /// 列表底部的一句说明。传空就不画。
    var footer: String = ""
    var onOpen: (Companion) -> Void

    private var sections: [ContactGrouping.Section] {
        ContactGrouping.sections(characters)
    }

    var body: some View {
        if sections.isEmpty {
            Text("还没有联系人")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.cream.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sections) { section in
                            sectionHeader(section.id)
                                .id(section.id)

                            ForEach(section.items) { character in
                                row(character)
                            }
                        }

                        if !footer.isEmpty {
                            Text(footer)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.cream.opacity(0.45))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .glassSurface(cornerRadius: 18)
                                .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .overlay(alignment: .trailing) { indexBar(proxy) }
            }
        }
    }

    // MARK: - 行

    private func sectionHeader(_ letter: String) -> some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.mint)

            Rectangle()
                .fill(Theme.mint.opacity(0.18))
                .frame(height: 1)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func row(_ character: Companion) -> some View {
        Button {
            onOpen(character)
        } label: {
            HStack(spacing: 12) {
                AvatarBubble(character: character, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(character.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(1)

                        if character.isGroup { badge("群") }
                        if CharacterClock.isAsleep(character) { badge("睡了") }
                    }

                    Text(subtitle(character))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.cream.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mint.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .glassSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private func subtitle(_ character: Companion) -> String {
        if !character.signature.isEmpty { return character.signature }
        let tags = character.tags.joined(separator: " · ")
        return tags.isEmpty ? "还没写简介" : tags
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.mint.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.mint.opacity(0.14))
            )
    }

    // MARK: - 索引条

    /// 只画有人的字母。A 到 Z 全列出来但大半点不动，反而更难点准。
    private func indexBar(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(sections.map(\.id), id: \.self) { letter in
                Button {
                    proxy.scrollTo(letter, anchor: .top)
                } label: {
                    Text(letter)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.mint.opacity(0.62))
                        .frame(width: 16, height: 13)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 1)
        .background(
            Capsule().fill(Theme.deepGreen.opacity(0.3))
        )
        .padding(.trailing, 4)
    }
}
