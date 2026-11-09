import SwiftUI

/// 角色的记忆。
///
/// 事实、概括、心事、日子四类摊成同一个流，靠上面的筛选分开看。
/// 之前是三个分区各写一套行、一套排版，改一句话得去三处；
/// 现在只有一种条目，点开就是同一个编辑器。
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
            days: world.characterDays(named: character.name, limit: 30)
        )
    }

    private var shown: [MemoryItem] {
        guard let filter else { return all }
        return all.filter { $0.kind == filter }
    }

    var body: some View {
        AppPage(title: "记忆") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    filterStrip

                    GroupedSection(
                        nil,
                        footer: "点一条可以改文字。模型记错了人名就改这里——留着错的，之后每轮都跟着错。"
                    ) {
                        if shown.isEmpty {
                            placeholder(all.isEmpty ? "还没有任何记忆。多聊几次，值得留下的会自己进来。" : "这个分类下暂时没有。")
                        } else {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                                row(item)
                                if index != shown.count - 1 {
                                    RowDivider()
                                }
                            }
                        }
                    }

                    countsSection
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

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                chip(title: "全部", count: all.count, selected: filter == nil) {
                    filter = nil
                }

                ForEach(MemoryItem.Kind.allCases) { kind in
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
                        Text(item.kind == .day ? "那天没留下概括，可以补一句" : "（空）")
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
                            .lineLimit(item.kind == .summary ? 6 : 3)
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

    private func tint(_ kind: MemoryItem.Kind) -> Color {
        switch kind {
        case .fact: return Theme.IconTint.teal
        case .voice: return Theme.IconTint.purple
        case .summary: return Theme.IconTint.gray
        case .day: return Theme.retroGreen
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

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PhoneMetrics.Space.m)
    }
}
