import SwiftUI

/// 一本书的全部批注，集中一处看。
///
/// 批注原本只长在正文里：想回头看写过什么，得翻到那一页、找那句话。
/// 这一页把它们按时间排开，点一条跳回原文——「集中看」和「定位」分开做。
struct BookNotesPage: View {
    let book: ReadingBook
    var onJump: (String) -> Void
    var onDelete: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var notes: [BookNote] {
        book.notes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.m) {
                    if notes.isEmpty {
                        empty
                    } else {
                        GroupedSection(
                            "\(notes.count) 条批注",
                            footer: "点一条跳回原文里的那句。长按可以删。"
                        ) {
                            ForEach(notes) { note in
                                row(note)
                                if note.id != notes.last?.id {
                                    RowDivider()
                                }
                            }
                        }
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(AppSurface.light.background)
            .navigationTitle("批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.medium, .large])
    }

    private func row(_ note: BookNote) -> some View {
        Button {
            onJump(note.sentence)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(note.sentence)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(2)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.tint)
                            .frame(width: 2)
                    }

                Text(note.text)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

                Text(TimeFormat.monthDayTime(note.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(note.id)
            } label: {
                Label("删掉这条批注", systemImage: "trash")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            Text("这本书还没有批注")
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(AppSurface.light.label)

            Text("在正文里长按一句就能写，写完会出现在这里。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
