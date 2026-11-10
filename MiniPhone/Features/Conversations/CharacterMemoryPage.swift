import SwiftUI

/// 角色的记忆。
///
/// 事实、概括、心事、日子四类摊成同一个流，靠上面的筛选分开看。
/// 群另走分栏：上面一块是群里共同的事，下面每个成员各一块「他自己记住的」。
/// 群视角落在成员自己的 `groupNotes[群名]` 里，不写回群名下——混在一起
/// 就等于把「谁记得什么」抹成「群里记得什么」。
struct CharacterMemoryPage: View {
    let character: Companion
    let world: WorldStore

    @State private var filter: MemoryItem.Kind?
    @State private var editing: MemoryItem?

    private var person: PersonMemory? {
        world.state.people.first { $0.name == character.name }
    }

    private var all: [MemoryItem] {
        MemoryItem.collect(
            person: person,
            // 群不排日程。按群名去取会拿到一张空表，但语义上就不该查。
            days: character.isGroup ? [] : world.characterDays(named: character.name, limit: 30),
            group: character.isGroup ? character.name : "",
            notes: character.isGroup ? world.groupNotes(in: character.name) : [:]
        )
    }

    private var shown: [MemoryItem] {
        guard let filter else { return all }
        return all.filter { $0.kind == filter }
    }

    /// 分栏名单。成员表没同步过的新群回退到角色上的名单字符串，
    /// 否则第一次点进来一个成员都没有，看着像没记住任何人。
    private var memberNames: [String] {
        let roster = world.groupRoster(named: character.name)
        guard roster.isEmpty else { return roster }
        return character.membersNote
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != character.name }
    }

    var body: some View {
        AppPage(title: character.isGroup ? "群里的记忆" : "记忆") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    filterStrip

                    if character.isGroup {
                        groupSections
                    } else {
                        soloSection
                    }

                    if character.isGroup { groupCounts } else { countsSection }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .sheet(item: $editing) { item in
            MemoryItemEditor(item: item, characterName: character.name, world: world)
        }
    }

    // MARK: - 筛选

    private var visibleKinds: [MemoryItem.Kind] {
        // 群没有心事和日子，这两个筛选留在上面只会多两颗恒为 0 的胶囊。
        character.isGroup ? [.summary, .fact, .groupNote] : MemoryItem.Kind.allCases
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                chip(title: "全部", count: all.count, selected: filter == nil) {
                    filter = nil
                }

                ForEach(visibleKinds) { kind in
                    let count = all.filter { $0.kind == kind }.count
                    chip(title: kind.label, count: count, selected: filter == kind) {
                        filter = kind
                    }
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
        }
    }

    private func chip(title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: selected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.7)
            }
            .foregroundStyle(selected ? Color.white : Theme.label)
            .padding(.horizontal, PhoneMetrics.Space.s)
            .frame(height: 30)
            .background {
                Capsule()
                    .fill(selected ? Theme.brand : Theme.separator.opacity(0.22))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 单人：一个流

    private var soloSection: some View {
        GroupedSection(
            nil,
            footer: "点一条可以改文字。模型记错了人名就改这里——留着错的，之后每轮都跟着错。"
        ) {
            if shown.isEmpty {
                placeholder(all.isEmpty ? "还没有任何记忆。多聊几次，值得留下的会自己进来。" : "这个分类下暂时没有。")
            } else {
                itemList(shown)
            }
        }
    }

    // MARK: - 群：共同一块，每人一块

    @ViewBuilder
    private var groupSections: some View {
        let shared = shown.filter { $0.notePerson == nil }

        GroupedSection(
            "群里共同的事",
            footer: "这一段谁都读得到：群聊里每个人，以及跟其中任何一个人单聊时。点一条可以改。"
        ) {
            if shared.isEmpty {
                placeholder(all.isEmpty ? "还没有任何记忆。多聊几次，值得留下的会自己进来。" : "这个分类下暂时没有。")
            } else {
                itemList(shared)
            }
        }

        ForEach(memberNames, id: \.self) { name in
            let rows = shown.filter { $0.notePerson == name }
            // 筛选到别的分类时不必留一排空的成员栏；「全部」时每人都有一块，
            // 还没记下的给一条空占位，点开就能补一句。
            if !rows.isEmpty || filter == nil {
                GroupedSection(
                    "\(name) 记住的",
                    footer: "只有他自己开口时、以及跟他单聊时读得到。群里其他人看不到这一份。"
                ) {
                    itemList(rows.isEmpty ? [emptyNote(for: name)] : rows)
                }
            }
        }
    }

    /// 还没留下笔记的成员也给一个可编辑条目，不进 `all`，
    /// 否则筛选条上的「群视角」会把空栏算成一条记忆。
    private func emptyNote(for name: String) -> MemoryItem {
        MemoryItem(
            id: "groupNote-empty-\(name)",
            kind: .groupNote,
            text: "",
            createdAt: Date(timeIntervalSince1970: 1),
            source: "点一下补一句",
            notePerson: name,
            noteGroup: character.name
        )
    }

    @ViewBuilder
    private func itemList(_ items: [MemoryItem]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(item)
            if index != items.count - 1 {
                RowDivider()
            }
        }
    }

    // MARK: - 一行

    private func row(_ item: MemoryItem) -> some View {
        Button {
            editing = item
        } label: {
            HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.kind == .voice && !item.isOpen
                                     ? Theme.secondaryLabel.opacity(0.6)
                                     : tint(item.kind))
                    .frame(width: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    if item.text.isEmpty {
                        Text(emptyHint(item.kind))
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel.opacity(0.8))
                    } else {
                        Text(item.text)
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(item.isOpen || item.kind != .voice
                                             ? Theme.label
                                             : Theme.secondaryLabel)
                            .strikethrough(item.kind == .voice && !item.isOpen,
                                           color: Theme.secondaryLabel.opacity(0.5))
                            .lineLimit(item.kind == .summary || item.kind == .groupNote ? 6 : 3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 4) {
                        Text(item.source)
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(Theme.secondaryLabel.opacity(0.85))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.secondaryLabel.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emptyHint(_ kind: MemoryItem.Kind) -> String {
        switch kind {
        case .day: return "那天没留下概括，可以补一句"
        case .groupNote: return "还没记下什么，点一下补一句"
        default: return "（空）"
        }
    }

    private func tint(_ kind: MemoryItem.Kind) -> Color {
        switch kind {
        case .fact: return Theme.IconTint.teal
        case .voice: return Theme.IconTint.purple
        case .summary: return Theme.IconTint.gray
        case .day: return Theme.retroGreen
        case .groupNote: return Theme.IconTint.indigo
        }
    }

    // MARK: - 底部统计

    private var countsSection: some View {
        GroupedSection("一眼看过去", footer: "这些数只统计这个角色。全局设定和历史在世界书里。") {
            GroupedRow(title: "记得的事实", value: "\(all.filter { $0.kind == .fact }.count) 条")
            RowDivider()
            GroupedRow(title: "没放下的心事", value: "\(all.filter { $0.kind == .voice && $0.isOpen }.count) 条")
            RowDivider()
            GroupedRow(title: "留下概括的日子", value: "\(all.filter { $0.kind == .day && !$0.text.isEmpty }.count) 天")
        }
    }

    private var groupCounts: some View {
        GroupedSection(
            "一眼看过去",
            footer: "共同的事谁都读得到；每人的视角只在他自己开口、以及跟他单聊时读到。"
        ) {
            GroupedRow(title: "群成员", value: "\(memberNames.count) 人")
            RowDivider()
            GroupedRow(title: "各自记下的", value: "\(all.filter { $0.kind == .groupNote }.count) 份")
            RowDivider()
            GroupedRow(title: "共同记下的", value: "\(all.filter { $0.notePerson == nil }.count) 条")
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PhoneMetrics.Space.m)
    }
}
