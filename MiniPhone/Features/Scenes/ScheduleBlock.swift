import SwiftUI

/// 时间轴上的一条日程。
///
/// 系统日历的日视图是「左侧时间、中间一条时间线、右侧事件块」，
/// 时间线一路连到下一个事件，读起来才像一天在往下走。
/// 之前是「时间 + 一根色条 + 一块浅底」，块与块之间断开，看着像卡片列表。
struct ScheduleBlock: View {
    let item: ScheduleItem
    /// 最后一条不再往下画线，否则会拖出一截没有去处的竖线。
    var isLast: Bool = false

    private var tint: Color { MoodColor.of(item.mood) }

    /// 已经过去的时段压暗一档，让「现在走到哪」有参照。
    private var isPast: Bool {
        item.hour < Calendar.current.component(.hour, from: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.xs) {
            Text(item.timeText)
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(isPast ? Theme.secondaryLabel.opacity(0.6) : Theme.secondaryLabel)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 8)

            rail

            block
        }
    }

    private var rail: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(tint.opacity(isPast ? 0.55 : 1))
                .frame(width: 7, height: 7)
                .padding(.top, 10)

            Rectangle()
                .fill(Theme.separator.opacity(0.65))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 7)
    }

    private var block: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(Theme.label)
                .opacity(isPast ? 0.75 : 1)

            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 5) {
                Image(systemName: item.mood.symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(item.mood.label)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
            }
            .foregroundStyle(tint)
            .padding(.top, 1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous)
                .fill(tint.opacity(isPast ? 0.06 : 0.11))
        )
        // 间距留在这块里，时间线才能一路连到下一行。
        .padding(.bottom, PhoneMetrics.Space.m)
    }
}
