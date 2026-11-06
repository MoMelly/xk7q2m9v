import SwiftData
import SwiftUI

/// 改一个表情的备注名和分组。
///
/// 备注名是这个表情唯一能进提示词的东西——没有名字，模型不知道
/// 「这张脸表示什么」，也就没法在对话里挑它。
struct StickerEditorSheet: View {
    @Bindable var sticker: StickerItem
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    preview
                    nameSection
                    groupSection
                    deleteSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("改表情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        try? context.save()
                        dismiss()
                    }
                    .foregroundStyle(Theme.brand)
                }
            }
        }
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .presentationDetents([.medium, .large])
    }

    private var preview: some View {
        GroupedSection {
            HStack {
                Spacer(minLength: 0)
                StickerView(item: sticker, size: 96)
                Spacer(minLength: 0)
            }
            .padding(.vertical, PhoneMetrics.Space.m)
        }
    }

    private var nameSection: some View {
        GroupedSection(
            "备注名",
            footer: "短一点，比如「开心」「无语」「摸摸头」。角色在提示词里看到的就是这几个字。"
        ) {
            TextField("备注名", text: $sticker.name)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private var groupSection: some View {
        GroupedSection(
            "分组",
            footer: "留空就是未分组。给角色开放表情时可以整组开关。"
        ) {
            TextField("分组", text: $sticker.group)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private var deleteSection: some View {
        GroupedSection {
            Button {
                onDelete()
                dismiss()
            } label: {
                Text("删除这个表情")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: PhoneMetrics.Row.single)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
