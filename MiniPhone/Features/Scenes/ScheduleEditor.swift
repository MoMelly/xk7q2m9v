import SwiftUI

/// 一条日程的查看 / 编辑。
///
/// 一条日程只有四样东西：几点、做什么、当时什么心情、备注。所以要的是
/// 一个能把四样都改掉的地方，不是一个只读详情页——真机上日程点开来就是能改的。
struct ScheduleEditor: View {
    let original: ScheduleItem?
    let onSave: (ScheduleItem) -> Void
    var onDelete: ((ScheduleItem) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hour: Int
    @State private var note: String
    @State private var mood: Mood

    init(
        item: ScheduleItem?,
        onSave: @escaping (ScheduleItem) -> Void,
        onDelete: ((ScheduleItem) -> Void)? = nil
    ) {
        self.original = item
        self.onSave = onSave
        self.onDelete = onDelete

        let now = Calendar.current.component(.hour, from: Date())
        _title = State(initialValue: item?.title ?? "")
        _hour = State(initialValue: item?.hour ?? min(now + 1, 23))
        _note = State(initialValue: item?.note ?? "")
        _mood = State(initialValue: item?.mood ?? .calm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    titleField
                    timeRow
                    moodRow
                    noteField

                    if let original, let onDelete {
                        Button(role: .destructive) {
                            Haptics.warn()
                            onDelete(original)
                            dismiss()
                        } label: {
                            Text("删除这条")
                                .font(.system(size: PhoneMetrics.FontSize.sub))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background {
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                        .fill(Theme.rowSurface)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(Theme.backgroundGradient)
            .navigationTitle(original == nil ? "添加安排" : "这条安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedTitle.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("做什么")
            TextField("比如 去趟打印店", text: $title)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .padding(.horizontal, PhoneMetrics.Space.s)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(Theme.rowSurface)
                }
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("几点")
            Picker("几点", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d:00", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 108)
            .clipped()
            .background {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(Theme.rowSurface)
            }
        }
    }

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("当时的心情")
            HStack(spacing: PhoneMetrics.Space.xs) {
                ForEach(Mood.allCases) { item in
                    Button {
                        Haptics.select()
                        mood = item
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15))
                            Text(item.label)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(mood == item ? .white : Theme.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                                .fill(mood == item ? MoodColor.of(item) : Theme.rowSurface)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("备注")
            TextField("想记一句就写", text: $note, axis: .vertical)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .lineLimit(2...5)
                .padding(PhoneMetrics.Space.s)
                .background {
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(Theme.rowSurface)
                }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
            .foregroundStyle(Theme.secondaryLabel)
            .padding(.leading, 4)
    }

    private func save() {
        let item = ScheduleItem(
            id: original?.id ?? UUID(),
            hour: hour,
            title: trimmedTitle,
            mood: mood,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(item)
        Haptics.tap()
        dismiss()
    }
}
