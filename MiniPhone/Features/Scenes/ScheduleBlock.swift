import SwiftUI

/// 时间轴上的一条日程。
///
/// 系统日历的事件块是这个形状：左侧起始时间，右侧一根细色条加浅色底，
/// 标题在上、备注在下。之前是「居中图标 + 两行文字 + 右边时间」，读起来像待办清单。
struct ScheduleBlock: View {
    let item: ScheduleItem

    private var tint: Color { MoodColor.of(item.mood) }

    var body: some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            Text(item.timeText)
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
                .frame(width: 42, alignment: .trailing)
                .padding(.top, 11)

            HStack(alignment: .top, spacing: 9) {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.bar, style: .continuous)
                    .fill(tint)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                        .foregroundStyle(Theme.label)

                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("\(item.mood.label) · 1 小时")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(tint)
                }
                .padding(.vertical, 9)
                .padding(.trailing, 10)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
        }
        .padding(.bottom, PhoneMetrics.Space.xs)
    }
}
