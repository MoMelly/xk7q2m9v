import SwiftData
import SwiftUI

/// 记忆库：整个世界走到哪一步了。
///
/// 角色页看的是「他记得什么」，这一页看的是「这个世界里一共留下了什么」——
/// 全局设定（对所有人生效的那几条）加上每个角色的一行进度。
/// 之前全局条目只有数据、没有入口：建得出来，但没有任何一处能看到它们。
struct MemoryLibraryPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Companion.sortIndex)]) private var companions: [Companion]
    @Query(sort: [SortDescriptor(\WorldEntry.createdAt, order: .reverse)])
    private var entries: [WorldEntry]

    @State private var editing: WorldEntry?
    @State private var creating = false

    private var world: WorldStore { .shared }

    private var globals: [WorldEntry] {
        entries.filter(\.isGlobal)
    }

    private var people: [PersonMemory] { world.state.people }

    /// 「聊过的人」。群不算人：这里数的是能一对一说话的对象。
    private var chatCount: Int {
        companions.filter { !$0.isFeedOnly && !$0.isGroup }.count
    }

    var body: some View {
        AppPage(title: "记忆库") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    overviewSection
                    globalSection
                    peopleSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $creating) {
            WorldEntryEditor(entry: nil, defaultOwner: nil, ownerName: "所有人")
        }
        .sheet(item: $editing) { entry in
            WorldEntryEditor(entry: entry, defaultOwner: nil, ownerName: "所有人")
        }
    }

    // MARK: - 概览

    private var overviewSection: some View {
        GroupedSection(
            nil,
            footer: "数字只统计当前这个世界。换世界是另一套记忆，不会混在一起。"
        ) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: PhoneMetrics.Space.s),
                          GridItem(.flexible(), spacing: PhoneMetrics.Space.s)],
                spacing: PhoneMetrics.Space.s
            ) {
                stat("聊过的人", "\(chatCount)", "person.2.fill", Theme.IconTint.teal)
                stat("记住的事", "\(people.reduce(0) { $0 + $1.facts.count })", "pin.fill", Theme.IconTint.orange)
                stat("没放下的心事", "\(people.reduce(0) { $0 + $1.voices.filter { !$0.isResolved }.count })", "bubble.left.fill", Theme.IconTint.purple)
                stat("全局设定", "\(globals.count)", "globe.asia.australia.fill", Theme.IconTint.indigo)
            }
            .padding(PhoneMetrics.Space.s)
        }
    }

    private func stat(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.label)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PhoneMetrics.Space.s)
        .padding(.vertical, PhoneMetrics.Space.s)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                .fill(Theme.separator.opacity(0.12))
        )
    }

    // MARK: - 全局设定

    private var globalSection: some View {
        GroupedSection(
            "对所有人生效",
            footer: globals.isEmpty
                ? "还没有全局设定。世界观、城市、时代这类人人共用的事，加一条之后每个角色聊天时都会看到。"
                : "点一条可以改。这些条目对所有角色都参与匹配。"
        ) {
            if globals.isEmpty {
                Button {
                    creating = true
                } label: {
                    GroupedRow(
                        symbol: "plus.circle.fill",
                        symbolTint: Theme.IconTint.green,
                        title: "加一条全局设定",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(Array(sorted(globals).enumerated()), id: \.element.uid) { index, entry in
                    entryRow(entry)
                    if index != globals.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func sorted(_ list: [WorldEntry]) -> [WorldEntry] {
        list.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func entryRow(_ entry: WorldEntry) -> some View {
        Button {
            editing = entry
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.kind.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(badgeTint(entry.kind))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(badgeTint(entry.kind).opacity(0.13))
                        )

                    Text(entry.kind == .condition ? entry.conditionSummary
                         : (entry.kind == .keyword ? entry.keywordList.joined(separator: " · ") : entry.position.label))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if !entry.enabled {
                        Text("已停用")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }

                Text(entry.content)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(entry.enabled ? Theme.label : Theme.secondaryLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                entry.enabled.toggle()
                try? context.save()
            } label: {
                Label(entry.enabled ? "先停用" : "重新启用", systemImage: entry.enabled ? "eye.slash" : "eye")
            }
            Button(role: .destructive) {
                context.delete(entry)
                try? context.save()
            } label: {
                Label("删掉", systemImage: "trash")
            }
        }
    }

    private func badgeTint(_ kind: WorldTrigger) -> Color {
        switch kind {
        case .constant: return Theme.IconTint.rose
        case .condition: return Theme.IconTint.indigo
        case .keyword: return Theme.retroGreen
        }
    }

    // MARK: - 每个角色

    private var peopleSection: some View {
        GroupedSection(
            "每个角色记住了多少",
            footer: "点进去改具体条目。没聊过的角色不出现在这里。群不在这份清单里，它的记忆在群详情里。"
        ) {
            let rows = companions.filter { !$0.isFeedOnly && !$0.isNPC && !$0.isGroup }
            if rows.isEmpty {
                Text("还没有角色。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.uid) { index, character in
                    NavigationLink {
                        CharacterMemoryPage(character: character, world: world)
                    } label: {
                        GroupedRow(
                            title: character.name,
                            subtitle: subtitle(for: character),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    if index != rows.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func subtitle(for character: Companion) -> String {
        let person = people.first { $0.name == character.name }
        let facts = person?.facts.count ?? 0
        let open = person?.voices.filter { !$0.isResolved }.count ?? 0
        let days = WorldBookResolver.Conditions.daysBetween(character.createdAt, and: Date())

        var parts: [String] = []
        parts.append(days == 0 ? "今天加的" : "认识 \(days) 天")
        parts.append("\(facts) 条事实")
        if open > 0 { parts.append("\(open) 条心事") }
        return parts.joined(separator: " · ")
    }
}
