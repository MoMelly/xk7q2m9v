import SwiftUI
import SwiftData

/// 日历。
///
/// 两个页签，回答的是两个不同的问题：
/// 「我的」是我今天怎么过，只有一份，跟着这台手机走；
/// 「发现」是别人今天在干什么，每个角色各一份，只在当天聊过之后才有。
///
/// 角色那份不在每轮对话里生成，也不给所有角色预生成——点开才现造一份，
/// 没聊过的人连一行都不占。
struct CalendarScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @Query(sort: [SortDescriptor(\Companion.sortIndex)])
    private var characters: [Companion]

    @State private var tab: Tab = .mine
    @State private var selectedDay = Date()

    enum Tab: String, CaseIterable, Hashable {
        case mine = "我的"
        case discover = "发现"
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    private var items: [ScheduleItem] {
        isToday ? (world.state.schedule?.items ?? []) : []
    }

    private var todayAction: (() -> Void)? {
        guard !isToday else { return nil }
        return { selectedDay = Date() }
    }

    var body: some View {
        AppScreen(
            title: "日历",
            onClose: onClose,
            trailingTitle: (tab == .mine && !isToday) ? "今天" : nil,
            trailingAction: todayAction
        ) {
            VStack(spacing: 0) {
                SegmentedTabs(items: Tab.allCases, title: \.rawValue, selection: $tab)
                    .padding(.top, PhoneMetrics.Space.xs)
                    .padding(.horizontal, PhoneMetrics.Space.m)

                switch tab {
                case .mine:
                    mineTab
                case .discover:
                    discoverTab
                }
            }
        }
    }

    // MARK: - 我的

    private var mineTab: some View {
        VStack(spacing: 0) {
            monthHeader
            WeekStrip(selected: $selectedDay)
            RowDivider()
            timeline
        }
    }

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(TimeFormat.month(selectedDay))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.label)

            Text(TimeFormat.year(selectedDay))
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)

            Spacer(minLength: 0)

            if !items.isEmpty {
                Text("\(items.count) 件")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.l)
        .padding(.bottom, PhoneMetrics.Space.s)
    }

    private var timeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    emptyState(
                        symbol: "calendar.badge.clock",
                        title: isToday ? "今天没有安排" : "这天没有记录",
                        hint: isToday ? "聊过之后，日程会跟着当天的状态走" : nil
                    )
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ScheduleBlock(item: item, isLast: index == items.count - 1)
                    }
                    moodFooter
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.top, PhoneMetrics.Space.m)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    @ViewBuilder
    private var moodFooter: some View {
        if let mood = world.state.mood {
            HStack(spacing: PhoneMetrics.Space.s) {
                Circle()
                    .fill(MoodColor.of(mood.mood))
                    .frame(width: 8, height: 8)

                Text("现在 · \(mood.mood.label)")
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)

                Text(mood.reason)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
            .padding(PhoneMetrics.Space.s)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                    .fill(Theme.rowSurface)
            )
            .padding(.top, PhoneMetrics.Space.xs)
        }
    }

    // MARK: - 发现

    private var discoverTab: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.section) {
                if characters.isEmpty {
                    emptyState(
                        symbol: "person.2",
                        title: "还没有角色",
                        hint: "先去消息里建一个，这里才有东西可看"
                    )
                } else {
                    GroupedSection(
                        "今天",
                        footer: "只有今天说过话的角色才有日程。没聊的人不会凭空被安排一天。"
                    ) {
                        ForEach(characters) { character in
                            discoverRow(character)
                            if character.uid != characters.last?.uid {
                                RowDivider()
                            }
                        }
                    }
                }
            }
            .padding(.top, PhoneMetrics.Space.l)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    private func talkedToday(_ character: Companion) -> Bool {
        guard let last = character.lastMessageAt else { return false }
        return Calendar.current.isDateInToday(last)
    }

    @ViewBuilder
    private func discoverRow(_ character: Companion) -> some View {
        let talked = talkedToday(character)
        let day = world.characterDay(named: character.name)

        if talked {
            NavigationLink {
                CharacterDayPage(world: world, character: character)
            } label: {
                rowBody(character, talked: true, day: day)
            }
            .buttonStyle(.plain)
        } else {
            rowBody(character, talked: false, day: day)
        }
    }

    private func rowBody(_ character: Companion, talked: Bool, day: CharacterDay?) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            AvatarBubble(character: character, size: 38)
                .opacity(talked ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(talked ? Theme.label : Theme.secondaryLabel)

                Text(summary(for: character, talked: talked, day: day))
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            if talked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
            } else {
                Text("今天还没聊")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel.opacity(0.8))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    private func summary(for character: Companion, talked: Bool, day: CharacterDay?) -> String {
        guard talked else { return "没有记录" }
        guard let day, !day.items.isEmpty else { return "还没生成日程，点开看看" }
        let next = day.items.first { $0.hour >= Calendar.current.component(.hour, from: Date()) }
        if let next {
            return "\(day.mood.label) · \(next.timeText) \(next.title)"
        }
        return "\(day.mood.label) · 今天已经收尾了"
    }

    // MARK: - 空态

    private func emptyState(symbol: String, title: String, hint: String?) -> some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.7))

            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)

            if let hint {
                Text(hint)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
        .padding(.horizontal, PhoneMetrics.Space.l)
    }
}

/// 某个角色今天的时间轴。
///
/// 生成就发生在这里：第一次打开才落一份，之后同一天再进来读的是同一份。
struct CharacterDayPage: View {
    let world: WorldStore
    let character: Companion

    @State private var day: CharacterDay?

    var body: some View {
        AppPage(title: character.name) {
            ScrollView {
                VStack(spacing: 0) {
                    header

                    if let summary = day?.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.label.opacity(0.85))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(PhoneMetrics.Space.s)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: PhoneMetrics.Radius.block,
                                    style: .continuous
                                )
                                .fill(Theme.rowSurface)
                            )
                            .padding(.bottom, PhoneMetrics.Space.s)
                    }

                    if let day, !day.items.isEmpty {
                        ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                            ScheduleBlock(item: item, isLast: index == day.items.count - 1)
                        }
                    } else {
                        Text("今天还没有安排")
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear {
            guard day == nil else { return }
            day = world.ensureCharacterDay(
                named: character.name,
                wakeHour: character.wakeHour,
                sleepHour: character.sleepHour
            )
        }
    }

    private var header: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            AvatarBubble(character: character, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                    .foregroundStyle(Theme.label)

                Text(day.map { "\($0.mood.label) · \(TimeFormat.shortDate(Date()))" } ?? "正在排")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.s)
    }
}
