import SwiftUI

/// 日历顶部的一周日期条。
///
/// 系统日历的日视图就是这个结构：上面一行星期缩写，下面一行日期数字，
/// 今天用实心圆标出来。没有它，页面就只是「一个列表」。
struct WeekStrip: View {
    @Binding var selected: Date

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)

                Button {
                    selected = day
                } label: {
                    VStack(spacing: 5) {
                        Text(TimeFormat.weekdayNarrow(day))
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(isToday ? Theme.tint : Theme.secondaryLabel)

                        Text(TimeFormat.dayNumber(day))
                            .font(.system(size: 16, weight: isToday ? .semibold : .regular))
                            .foregroundStyle(isToday ? .white : Theme.label)
                            .frame(width: 31, height: 31)
                            .background {
                                Circle()
                                    .fill(isToday ? Theme.tint : .clear)
                            }
                            .overlay {
                                if isSelected && !isToday {
                                    Circle()
                                        .strokeBorder(Theme.tint, lineWidth: 1.5)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.s)
        .padding(.bottom, PhoneMetrics.Space.s)
    }
}
