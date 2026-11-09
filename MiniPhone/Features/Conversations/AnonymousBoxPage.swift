import SwiftUI

/// 匿名提问箱。
///
/// 问题是匿名的：角色不知道谁问的，答的时候也就没有「对你」这个前提。
/// 回答会被记进他的记忆——下次聊天里他可能自己提起「有人问过我……」，
/// 这正是这个箱子想要的效果：他多了一个你不知道的侧面。
struct AnonymousBoxPage: View {
    let character: Companion
    let world: WorldStore
    let settings: SettingsStore

    @State private var draft = ""
    @State private var sending = false
    @State private var errorText: String?

    private var items: [AnonymousQuestion] {
        world.questions(for: character.name)
    }

    var body: some View {
        AppPage(title: "匿名提问箱") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    introSection
                    composeSection
                    listSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .alert("没答上来", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("知道了", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private var introSection: some View {
        GroupedSection {
            Text("投一个问题进去，\(character.name)不知道是谁问的。\n答完会记进他的记忆，之后聊天他可能自己提起。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PhoneMetrics.Space.m)
        }
    }

    private var composeSection: some View {
        GroupedSection("问一句") {
            TextEditor(text: $draft)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72)
                .padding(.horizontal, PhoneMetrics.Space.s)
                .padding(.vertical, PhoneMetrics.Space.xs)
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("比如：你最近一次真心笑是什么时候？")
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .padding(.vertical, PhoneMetrics.Space.s)
                            .allowsHitTesting(false)
                    }
                }

            RowDivider()

            HStack {
                Spacer(minLength: 0)
                Button {
                    submit()
                } label: {
                    HStack(spacing: 5) {
                        if sending {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        }
                        Text(sending ? "等他说" : "投进去")
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(Capsule().fill(canSend ? Theme.brand : Theme.secondaryLabel.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private var canSend: Bool {
        !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var listSection: some View {
        if items.isEmpty {
            GroupedSection {
                Text("还没有人问过。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            }
        } else {
            GroupedSection("收到的问题") {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                    if index != items.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func row(_ item: AnonymousQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(item.asker)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.IconTint.purple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.IconTint.purple.opacity(0.13))
                    )

                Text(TimeFormat.clock(item.askedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryLabel)

                Spacer(minLength: 0)

                if item.answer.isEmpty {
                    if AnonymousBoxService.shared.isAnswering(item.id) {
                        Text("在想")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.secondaryLabel)
                    } else {
                        Button("让他答") {
                            ask(item)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.brand)
                    }
                }
            }

            Text(item.text)
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)

            if !item.answer.isEmpty {
                Text(item.answer)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, PhoneMetrics.Space.s)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.retroGreen.opacity(0.45))
                            .frame(width: 2)
                    }
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                world.deleteQuestion(id: item.id)
            } label: {
                Label("删掉这一问", systemImage: "trash")
            }
        }
    }

    // MARK: - 动作

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let id = world.appendQuestion(characterName: character.name, text: text) else {
            return
        }
        draft = ""
        sending = true
        Task {
            let failure = await AnonymousBoxService.shared.answer(
                questionID: id,
                question: text,
                character: character,
                settings: settings
            )
            sending = false
            if let failure { errorText = failure }
        }
    }

    private func ask(_ item: AnonymousQuestion) {
        Task {
            let failure = await AnonymousBoxService.shared.answer(
                questionID: item.id,
                question: item.text,
                character: character,
                settings: settings
            )
            if let failure { errorText = failure }
        }
    }
}
