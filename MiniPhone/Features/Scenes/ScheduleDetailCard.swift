import SwiftUI

/// 一条日程点开来先看的那一眼。
///
/// 「我的」时间轴上点一下，多半是想确认这件事几点、在哪、跟谁，
/// 不是马上要改它——所以先给一张半屏卡，改是第二步。
///
/// 卡上三件事：跟他提一句 / 改时间 / 删掉。提一句只把话放进聊天输入框，
/// 不替她按下发送键。
struct ScheduleDetailCard: View {
    let world: WorldStore

    @Environment(\.dismiss) private var dismiss
    @State private var item: ScheduleItem
    @State private var showEditor = false
    @State private var confirmingDelete = false
    @State private var staged = false

    init(item: ScheduleItem, world: WorldStore) {
        self.world = world
        _item = State(initialValue: item)
    }

    /// 「他」取最近说过话的那个人，跟主屏、日历页脚同一套口径。
    private var canTell: Bool {
        !world.primaryName.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.l) {
                    header
                    details
                }
                .padding(.horizontal, PhoneMetrics.Space.l)
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.l)
            }

            actions
                .padding(.horizontal, PhoneMetrics.Space.l)
                .padding(.bottom, PhoneMetrics.Space.l)
        }
        .background(AppSurface.light.background)
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showEditor) {
            ScheduleEditor(
                item: item,
                onSave: { saved in
                    world.upsertScheduleItem(saved)
                    item = saved
                    staged = false
                },
                onDelete: { gone in
                    world.deleteScheduleItem(id: gone.id)
                }
            )
        }
        .onChange(of: showEditor) { _, isShowing in
            // 在编辑页里把这条删了，卡片不该还留在后面。
            guard !isShowing else { return }
            let stillThere = world.state.schedule?.items.contains { $0.id == item.id } ?? false
            if !stillThere {
                dismiss()
            }
        }
        .alert("删掉这一条？", isPresented: $confirmingDelete) {
            Button("删掉", role: .destructive) {
                Haptics.warn()
                world.deleteScheduleItem(id: item.id)
                dismiss()
            }
            Button("留着", role: .cancel) {}
        } message: {
            Text("删掉之后，今天的安排就少这一件，不会自己回来。")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            Text(item.timeText)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppSurface.light.label)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                    .foregroundStyle(AppSurface.light.label)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: item.mood.symbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(item.mood.label)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                }
                .foregroundStyle(MoodColor.of(item.mood))
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.s) {
            if !item.place.isEmpty {
                row("地点", item.place)
            }
            if !item.companions.isEmpty {
                row("同去", item.companionsText)
            }
            if !item.note.isEmpty {
                row("备注", item.note)
            }
            if item.place.isEmpty && item.companions.isEmpty && item.note.isEmpty {
                Text("地点、同去、备注都还空着。点「改时间」可以补上。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            Text(value)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Button {
                tell()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: staged ? "checkmark" : "bubble.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(staged ? "已放进输入框" : "跟他提一句")
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(staged ? Theme.green : Theme.tint)
                }
            }
            .buttonStyle(.plain)
            .disabled(staged || !canTell)
            .opacity(canTell ? 1 : 0.45)

            HStack(spacing: PhoneMetrics.Space.s) {
                Button {
                    showEditor = true
                } label: {
                    Text("改时间")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.label)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                .fill(AppSurface.light.rowSurface)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    confirmingDelete = true
                } label: {
                    Text("删掉")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(Theme.pink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                .fill(AppSurface.light.rowSurface)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tell() {
        guard canTell else { return }
        Haptics.tap()
        world.stageChatDraft(sentence, for: world.primaryName)
        staged = true
    }

    /// 递过去的是一句人话，不是字段拼接：地点、同去有就带上，没有就不提。
    private var sentence: String {
        var text = "今天 \(item.timeText) 要去\(item.title)"
        if !item.place.isEmpty {
            text += "，在\(item.place)"
        }
        if !item.companions.isEmpty {
            text += "，和\(item.companionsText)一起"
        }
        return text + "。"
    }
}
