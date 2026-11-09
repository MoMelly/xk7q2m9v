import SwiftUI

/// 状态面板：这一轮提示词里，角色的处境长什么样。
///
/// 好感度、心情、地点、时间、今天的安排、世界变量，全都在这一页。
/// 之前这些值分散在三个页面里，改一个地点要去日历，调一个心情没有入口。
/// 现在它们放在一起，因为它们在提示词里本来就是一起出现的一整段。
struct StatePanelPage: View {
    let character: Companion
    let world: WorldStore

    @State private var affinity: Int = 30
    @State private var locationText: String = ""
    @State private var newKey = ""
    @State private var newValue = ""

    private var mood: MoodState? { world.mood(for: character.name) }
    private var today: DaySchedule? { world.todaySchedule(for: character.name) }
    private var stage: WorldStore.AffinityStage { WorldStore.stage(of: affinity) }

    private var variables: [(key: String, value: String)] {
        world.state.variables.sorted { $0.key < $1.key }
    }

    var body: some View {
        AppPage(title: "状态") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    affinitySection
                    nowSection
                    scheduleSection
                    variableSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear {
            affinity = world.affinity(for: character.name)
            locationText = world.location(for: character.name)
        }
        .onDisappear {
            world.setLocation(locationText, for: character.name)
        }
    }

    // MARK: - 好感度

    private var affinitySection: some View {
        GroupedSection(
            "关系",
            footer: "每聊一轮往前挪一格。也可以直接拖——这是给语气用的刻度，不是要打的分数，谁都不会因为你调了它而改台词。"
        ) {
            VStack(spacing: PhoneMetrics.Space.s) {
                HStack(alignment: .center, spacing: PhoneMetrics.Space.m) {
                    ring

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage.label)
                            .font(.system(size: PhoneMetrics.FontSize.largeTitle, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.label)

                        Text(stage.line)
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Slider(
                    value: Binding(
                        get: { Double(affinity) },
                        set: { newValue in
                            affinity = Int(newValue.rounded())
                            world.setAffinity(affinity, for: character.name)
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(Theme.brand)
            }
            .padding(PhoneMetrics.Space.m)
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.separator.opacity(0.35), lineWidth: 7)
                .frame(width: 68, height: 68)

            Circle()
                .trim(from: 0, to: CGFloat(affinity) / 100)
                .stroke(
                    AngularGradient(
                        colors: [Theme.mint, Theme.retroGreen, Theme.deepGreen],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 68, height: 68)

            Text("\(affinity)")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.label)
                .monospacedDigit()
        }
    }

    // MARK: - 此刻

    private var nowSection: some View {
        GroupedSection(
            "此刻",
            footer: "心情是聊天和日程自己推出来的，这里是只读的；地点可以改，改完下一轮提示词就跟着变。"
        ) {
            if let mood {
                GroupedRow(
                    title: "心情",
                    subtitle: mood.reason.isEmpty ? nil : mood.reason,
                    value: mood.mood.label
                )
                RowDivider()
            }

            HStack {
                Text("在哪")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: PhoneMetrics.Space.s)

                TextField("没写过", text: $locationText)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.brand)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        world.setLocation(locationText, for: character.name)
                    }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)

            RowDivider()

            GroupedRow(title: "现在", value: currentTimeLine)
            RowDivider()
            GroupedRow(title: "作息", value: "\(character.wakeHour) 点起 · \(character.sleepHour) 点睡")
        }
    }

    private var currentTimeLine: String {
        let now = Date()
        let hour = CharacterClock.calendar.component(.hour, from: now)
        let phase = DayPhase.of(hour: hour)
        let asleep = CharacterClock.isAsleep(character, at: now)
        return "\(TimeFormat.clock(now)) · \(phase.label)\(asleep ? " · 睡着" : "")"
    }

    // MARK: - 今天的安排

    private var scheduleSection: some View {
        GroupedSection(
            "今天的安排",
            footer: "这一份是从他今天的时间轴上读出来的。想改就去日历里改，这里不重复编辑。"
        ) {
            if let items = today?.items, !items.isEmpty {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: PhoneMetrics.Space.s) {
                        Text(item.timeText)
                            .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                            .foregroundStyle(Theme.secondaryLabel)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .leading)

                        Text(item.title)
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(Theme.label)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Circle()
                            .fill(MoodColor.of(item.mood))
                            .frame(width: 7, height: 7)
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)

                    if index != items.count - 1 {
                        RowDivider()
                    }
                }
            } else {
                Text("今天还没排。在他日历里点一下就会生成。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            }
        }
    }

    // MARK: - 世界变量

    private var variableSection: some View {
        GroupedSection(
            "世界变量",
            footer: "一句话能说完的事放这里：天气、季节、你们第一次见面的日子。整张表都会进提示词，最多带 12 条。"
        ) {
            ForEach(variables, id: \.key) { item in
                HStack(spacing: PhoneMetrics.Space.s) {
                    Text(item.key)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: PhoneMetrics.Space.xs)

                    Text(item.value)
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        world.removeVariable(item.key)
                    } label: {
                        Label("删掉这个变量", systemImage: "trash")
                    }
                }

                RowDivider()
            }

            HStack(spacing: PhoneMetrics.Space.xs) {
                TextField("名字", text: $newKey)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.brand)
                    .frame(maxWidth: 82)

                Divider()
                    .frame(height: 16)

                TextField("一句话", text: $newValue)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.brand)

                Button("加入") {
                    world.setVariable(newValue, for: newKey)
                    newKey = ""
                    newValue = ""
                }
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(canAddVariable ? Theme.brand : Theme.secondaryLabel)
                .disabled(!canAddVariable)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private var canAddVariable: Bool {
        !newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
