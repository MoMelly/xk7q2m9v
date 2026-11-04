import SwiftUI

/// 假状态栏。
///
/// 系统状态栏在外壳里被隐藏了，这一条完全是画出来的。
/// 信号条和电池刻意手绘：直接用 SF Symbol 的 `cellularbars` 和 `battery.100`
/// 比例偏胖，一眼就能看出是拼的，反而不如自己按 iOS 的尺寸画。
struct StatusBarView: View {
    var tint: Color = .white

    private let horizontalPadding: CGFloat = 28

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 0) {
                Text(TimeFormat.clock(context.date))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    CellularBars(tint: tint)
                    WifiGlyph(tint: tint)
                    BatteryGlyph(tint: tint)
                }
            }
            .foregroundStyle(tint)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .padding(.horizontal, horizontalPadding)
            .frame(height: PhoneMetrics.statusBarHeight)
        }
    }
}

/// 四格信号。前三级点亮，最后一级留暗，模拟满格边缘的常见状态。
private struct CellularBars: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(tint.opacity(index < 3 ? 1 : 0.35))
                    .frame(width: 3, height: 4 + CGFloat(index) * 2.2)
            }
        }
        .frame(height: 11, alignment: .bottom)
    }
}

private struct WifiGlyph: View {
    let tint: Color

    var body: some View {
        Image(systemName: "wifi")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
    }
}

/// 电池。外框只描边，内部按 60% 电量填充，右侧留一枚小凸点。
private struct BatteryGlyph: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1)

                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                    .fill(tint)
                    .frame(width: 13, height: 7)
                    .padding(.leading, 2.5)
            }
            .frame(width: 24, height: 12)

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tint.opacity(0.45))
                .frame(width: 1.5, height: 4)
        }
    }
}
