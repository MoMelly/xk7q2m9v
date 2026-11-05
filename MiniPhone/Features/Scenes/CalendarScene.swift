import SwiftUI

/// 日历。
///
/// 按系统「日历」日视图的结构排：月份标题、一周日期条、时间轴事件块。
/// 世界状态里只有当天一份日程，点到别的日期就是空态，不假装那天有安排。
struct CalendarScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var selectedDay = Date()

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
            trailingTitle: isToday ? nil : "今天",
            trailingAction: todayAction
        ) {
            VStack(spacing: 0) {
                monthHeader
                WeekStrip(selected: $selectedDay)
                RowDivider()
                timeline
            }
        }
    }

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(TimeFormat.year(selectedDay))
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)

            Text(TimeFormat.month(selectedDay))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.label)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.l)
        .padding(.top, PhoneMetrics.Space.xs)
        .padding(.bottom, PhoneMetrics.Space.s)
    }

    private var timeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(items) { item in
                        ScheduleBlock(item: item)
                    }
                    moodFooter
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.l)
            .padding(.top, PhoneMetrics.Space.m)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.secondaryLabel)

            Text(isToday ? "今天没有安排" : "这天没有记录")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var moodFooter: some View {
        if let mood = world.state.mood {
            HStack(spacing: PhoneMetrics.Space.s) {
                Circle()
                    .fill(MoodColor.of(mood.mood))
                    .frame(width: 8, height: 8)

                Text("当前状态 · \(mood.mood.label)")
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)

                Text(mood.reason)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .padding(PhoneMetrics.Space.s)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                    .fill(Theme.rowSurface)
            )
            .padding(.top, PhoneMetrics.Space.s)
        }
    }
}
