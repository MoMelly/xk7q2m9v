import SwiftData
import SwiftUI

/// 这个角色能用哪些表情。
///
/// 存的是「禁用名单」而不是「开放名单」：新传的表情默认所有角色都能用，
/// 只把不适配的关掉。反过来每加一个表情就得回来给每个角色勾一遍。
struct CharacterStickerPage: View {
    @Bindable var character: Companion

    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.l) {
                summarySection
                if groups.isEmpty {
                    emptySection
                } else {
                    ForEach(groups, id: \.self) { group in
                        groupSection(group)
                    }
                }
            }
            .padding(.top, PhoneMetrics.Space.s)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .background(Theme.groupedBackground)
        .navigationTitle("能用哪些表情")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    // MARK: - 数据

    private var items: [StickerItem] {
        StickerLibrary.shared.items
    }

    /// 空分组名排最后：它是「没归类的」，不该排在正经分组前面。
    private var groups: [String] {
        var named: [String] = []
        var hasUnnamed = false
        for item in items {
            if item.group.isEmpty {
                hasUnnamed = true
            } else if !named.contains(item.group) {
                named.append(item.group)
            }
        }
        return hasUnnamed ? named + [""] : named
    }

    private func items(in group: String) -> [StickerItem] {
        items.filter { $0.group == group }
    }

    private var openCount: Int {
        StickerLibrary.shared.available(for: character).count
    }

    // MARK: - 分区

    private var summarySection: some View {
        GroupedSection(
            footer: "关掉的表情不会出现在提示词里，角色也就想不到要发。已经发过的历史消息不动。"
        ) {
            HStack {
                Text("能用 \(openCount) / \(items.count) 个")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private var emptySection: some View {
        GroupedSection {
            VStack(alignment: .leading, spacing: PhoneMetrics.Space.xxs) {
                Text("还没有表情")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
                Text("去「设置 → 表情」里传一批，再回来给这个角色挑。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PhoneMetrics.Space.m)
        }
    }

    private func groupSection(_ group: String) -> some View {
        let members = items(in: group)
        let blocked = !group.isEmpty && isGroupBlocked(group)

        return GroupedSection(groupTitle(group), footer: groupFooter(group, blocked: blocked)) {
            // 整组开关只在有分组名时给：未分组本来就没法批量管理，
            // 给个「整组」开关等于逼人一个个关。
            if !group.isEmpty {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Text("整组")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                    Spacer(minLength: 0)
                    Toggle("", isOn: Binding(
                        get: { !blocked },
                        set: { setGroup(group, enabled: $0) }
                    ))
                    .labelsHidden()
                    .tint(Theme.brand)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)

                RowDivider()
            }

            ForEach(Array(members.enumerated()), id: \.offset) { index, item in
                stickerRow(item, muted: blocked)

                if index < members.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private func stickerRow(_ item: StickerItem, muted: Bool) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            StickerView(item: item, size: 32)
                .opacity(muted ? 0.4 : 1)

            Text(displayName(item))
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(muted ? Theme.secondaryLabel : Theme.label)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { muted || !isNameBlocked(item.name) },
                set: { setSticker(item, enabled: $0) }
            ))
            .labelsHidden()
            .tint(Theme.brand)
            .disabled(muted)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.single)
    }

    private func groupTitle(_ group: String) -> String {
        group.isEmpty ? "未分组" : group
    }

    private func groupFooter(_ group: String, blocked: Bool) -> String? {
        blocked ? "整组关掉了，下面单个的开关恢复整组才会生效。" : nil
    }

    private func displayName(_ item: StickerItem) -> String {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // 没名字的表情不会进提示词，这里要显眼一点，否则用户以为开了就能用。
        return trimmed.isEmpty ? "（未命名，角色用不了）" : trimmed
    }

    // MARK: - 读写

    private func isGroupBlocked(_ group: String) -> Bool {
        character.blockedStickerGroups.contains(group)
    }

    private func isNameBlocked(_ name: String) -> Bool {
        character.blockedStickerNames.contains(name)
    }

    private func setGroup(_ group: String, enabled: Bool) {
        var set = character.blockedStickerGroups
        if enabled {
            set.remove(group)
        } else {
            set.insert(group)
        }
        character.blockedStickerGroupsRaw = set.sorted().joined(separator: ",")
        try? context.save()
    }

    private func setSticker(_ item: StickerItem, enabled: Bool) {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        var set = character.blockedStickerNames
        if enabled {
            set.remove(name)
        } else {
            set.insert(name)
        }
        character.blockedStickerNamesRaw = set.sorted().joined(separator: ",")
        try? context.save()
    }
}
