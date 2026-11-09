import SwiftData
import SwiftUI

/// 设定集：角色的背景设定。
///
/// 按触发方式分三段——常驻、条件、关键词。这个分组不是排版，是「什么时候会带上」：
/// 常驻每轮都在，条件看状态，关键词看聊天里提没提。
/// 全局条目单独列在最后，它们对每个角色都算数。
struct WorldEntryListView: View {
    let character: Companion

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\WorldEntry.createdAt, order: .reverse)])
    private var allEntries: [WorldEntry]

    @Environment(\.dismiss) private var dismiss

    @State private var editing: WorldEntry?
    @State private var creating = false
    @State private var createGlobal = false

    private var mine: [WorldEntry] {
        allEntries.filter { $0.characterUID == character.uid }
    }

    private var globals: [WorldEntry] {
        allEntries.filter(\.isGlobal)
    }

    var body: some View {
        NavigationStack {
            AppPage(title: "设定集") {
                ScrollView {
                    VStack(spacing: PhoneMetrics.Space.xl) {
                        if mine.isEmpty && globals.isEmpty {
                            emptySection
                        }

                        ForEach(WorldTrigger.allCases) { kind in
                            let group = mine.filter { $0.kind == kind }
                            if !group.isEmpty {
                                section(kind: kind, entries: group)
                            }
                        }

                        if !globals.isEmpty {
                            globalSection
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.s)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("给\(character.name)加一条") {
                            createGlobal = false
                            creating = true
                        }
                        Button("对所有人生效") {
                            createGlobal = true
                            creating = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $creating) {
                WorldEntryEditor(
                    entry: nil,
                    defaultOwner: createGlobal ? nil : character.uid,
                    ownerName: character.name
                )
            }
            .sheet(item: $editing) { entry in
                WorldEntryEditor(
                    entry: entry,
                    defaultOwner: character.uid,
                    ownerName: character.name
                )
            }
        }
    }

    // MARK: - 分段

    private func section(kind: WorldTrigger, entries: [WorldEntry]) -> some View {
        GroupedSection(kind.label, footer: footer(kind)) {
            ForEach(Array(sorted(entries).enumerated()), id: \.element.uid) { index, entry in
                row(entry)
                if index != entries.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private var globalSection: some View {
        GroupedSection(
            "对所有人生效",
            footer: "世界观、城市、时代这类人人共用的事。每个角色聊天时都会看上这几条。"
        ) {
            ForEach(Array(sorted(globals).enumerated()), id: \.element.uid) { index, entry in
                row(entry)
                if index != globals.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private var emptySection: some View {
        GroupedSection {
            Text("还没有条目。\n\n常驻一条「你们住在城西，他每天骑车上下班」——不管聊什么，角色都知道这件事。\n\n条件条目写「他夜里不太愿意提工作」，只在夜里生效。\n\n关键词条目填「灯塔」，之后聊天里提到灯塔，那段才补进去。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PhoneMetrics.Space.m)
        }
    }

    private func footer(_ kind: WorldTrigger) -> String {
        switch kind {
        case .constant: return "每轮都带上。写在前面还是后面，由每条自己的位置决定。"
        case .condition: return "时段、心情、地点、认识天数对上才带上。"
        case .keyword: return "聊天里提到关键词才注入。"
        }
    }

    /// 优先级高的排前面，和真正进提示词的顺序一致——列表看着什么顺序，模型就读到什么顺序。
    private func sorted(_ entries: [WorldEntry]) -> [WorldEntry] {
        entries.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // MARK: - 一行

    private func row(_ entry: WorldEntry) -> some View {
        Button {
            editing = entry
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    tag("\(entry.priority)", tint: badgeTint(entry.kind))
                    tag(entry.position.label, tint: Theme.secondaryLabel)

                    if entry.kind == .condition {
                        Text(entry.conditionSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondaryLabel)
                            .lineLimit(1)
                    } else if entry.kind == .keyword {
                        Text(entry.keywordList.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.retroGreen)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if !entry.enabled {
                        Text("已停用")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }

                Text(entry.content)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(entry.enabled ? Theme.label : Theme.secondaryLabel)
                    .lineLimit(3)
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

    private func tag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.13))
            )
    }

    private func badgeTint(_ kind: WorldTrigger) -> Color {
        switch kind {
        case .constant: return Theme.IconTint.rose
        case .condition: return Theme.IconTint.indigo
        case .keyword: return Theme.retroGreen
        }
    }
}
