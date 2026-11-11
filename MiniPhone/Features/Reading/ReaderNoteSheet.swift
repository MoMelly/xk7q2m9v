import SwiftUI

/// 长按选中一句之后弹出来的输入卡。
///
/// 只做一件事：把「哪一句」和「想到什么」配起来存下。
/// 原句放在最上面，是因为小屏上写完想法，正文已经被键盘顶得看不见了，
/// 得有个地方能确认自己批的是哪句。
struct ReaderNoteEditor: View {
    let sentence: String
    @Binding var draft: String
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                quote

                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("这一句让你想到什么")
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $draft)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .frame(minHeight: 100)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(AppSurface.light.rowSurface)
                )

                Spacer(minLength: 0)
            }
            .padding(PhoneMetrics.Space.m)
            .background(AppSurface.light.background)
            .navigationTitle("写批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("存下") { onSave(trimmed) }
                        .disabled(trimmed.isEmpty)
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.height(320), .medium])
        .onAppear { focused = true }
    }

    private var quote: some View {
        Text(sentence)
            .font(.system(size: PhoneMetrics.FontSize.sub))
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .lineLimit(4)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.tint)
                    .frame(width: 2.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 点回已经批注过的那句，看自己当时写的什么，也能删掉。
struct ReaderNoteView: View {
    let note: BookNote
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(note.sentence)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(5)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.tint)
                            .frame(width: 2.5)
                    }

                Text(note.text)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(TimeFormat.monthDayTime(note.createdAt))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.7))

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    confirming = true
                } label: {
                    Text("删掉这条批注")
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                .fill(AppSurface.light.rowSurface)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(PhoneMetrics.Space.m)
            .background(AppSurface.light.background)
            .navigationTitle("批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { dismiss() }
                }
            }
            .alert("删掉这条批注？", isPresented: $confirming) {
                Button("删掉", role: .destructive) { onDelete() }
                Button("取消", role: .cancel) {}
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.height(320), .medium])
    }
}
