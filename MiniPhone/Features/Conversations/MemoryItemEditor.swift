import SwiftUI

/// 改一条记忆。
///
/// 四种条目共用这一张表：能改的就只有文字，加上心事专用的「放下 / 捡起」。
/// 之前记忆页整页只读，理由是「手改会让记忆和实际发生过的事对不上」——
/// 这个顾虑对「加一条」成立，对「改错字」不成立。模型记错一个人名，
/// 之后每轮都跟着错，能改才谈得上准确。
struct MemoryItemEditor: View {
    let item: MemoryItem
    let characterName: String
    let world: WorldStore

    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var resolved: Bool

    init(item: MemoryItem, characterName: String, world: WorldStore) {
        self.item = item
        self.characterName = characterName
        self.world = world
        _text = State(initialValue: item.text)
        _resolved = State(initialValue: !item.isOpen)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    editorSection
                    if item.kind == .voice { voiceSection }
                    detailSection
                    if item.kind != .summary { deleteSection }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("改\(item.kind.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.secondaryLabel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        apply()
                        dismiss()
                    }
                    .foregroundStyle(Theme.brand)
                }
            }
        }
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .presentationDetents([.medium, .large])
    }

    // MARK: - 文字

    private var editorSection: some View {
        GroupedSection(
            item.kind == .summary ? "概括" : "内容",
            footer: textFooter
        ) {
            TextEditor(text: $text)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(.horizontal, PhoneMetrics.Space.s)
                .padding(.vertical, PhoneMetrics.Space.xs)
        }
    }

    private var textFooter: String {
        switch item.kind {
        case .summary: return "这一段会整段进提示词。写长了他每轮都要读，别超过几行。"
        case .fact: return "改空了等于删掉。这一条每轮都会带上，写错了要改——留着错的，之后每轮都跟着错。"
        case .voice: return "这是他没说出口的话。改文字不会让它变成说出来过。"
        case .day: return "这一天的概括。改的是他记得的那一句，不是当天真实的对话记录。"
        }
    }

    // MARK: - 心事状态

    private var voiceSection: some View {
        GroupedSection(
            "状态",
            footer: resolved
                ? "放下了就不再提起，但留在列表里。哪天又提起，还能捡回来。"
                : "没放下的会一直在，直到被聊开。"
        ) {
            Toggle(isOn: $resolved) {
                Text("已经放下了")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
            }
            .tint(Theme.brand)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    // MARK: - 出处

    private var detailSection: some View {
        GroupedSection {
            GroupedRow(title: "类型", value: item.kind.label)
            RowDivider()
            GroupedRow(title: "记在谁那儿", value: characterName)
            if !item.source.isEmpty {
                RowDivider()
                GroupedRow(title: "出处", value: item.source)
            }
        }
    }

    // MARK: - 删

    private var deleteSection: some View {
        GroupedSection(footer: "删掉之后这一条不会再进提示词。已经聊过的对话不会跟着消失。") {
            Button(role: .destructive) {
                clear()
                dismiss()
            } label: {
                Text("删掉这一条")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.IconTint.pink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: PhoneMetrics.Row.single)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 写回

    private func apply() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch item.kind {
        case .summary:
            world.replaceMemorySummary(person: characterName, text: clean)
        case .fact:
            guard let id = item.factID else { return }
            world.updateFact(person: characterName, id: id, text: clean)
        case .voice:
            guard let id = item.voiceID else { return }
            world.updateVoice(person: characterName, id: id, text: clean)
            world.setVoiceResolved(person: characterName, id: id, resolved: resolved)
        case .day:
            world.updateDaySummary(named: characterName, dateKey: item.dateKey, summary: clean)
        }
    }

    private func clear() {
        switch item.kind {
        case .summary:
            world.replaceMemorySummary(person: characterName, text: "")
        case .fact:
            guard let id = item.factID else { return }
            world.deleteFact(person: characterName, id: id)
        case .voice:
            guard let id = item.voiceID else { return }
            world.updateVoice(person: characterName, id: id, text: "")
        case .day:
            world.updateDaySummary(named: characterName, dateKey: item.dateKey, summary: "")
        }
    }
}
