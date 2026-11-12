import SwiftUI

/// 主屏小组件。
///
/// 三块都只读世界状态，不自己造内容：今天排了什么、他现在什么心情、在放哪首歌。
/// 之前主屏只有两排图标、下面空一大片，看着不像一台被人用过的手机。
///
/// 尺寸按图标格算：宽组件横跨 4 格，两个方块各占 2 格。
/// 底座用 `frostedBar` 而不是 `frostedCard`——小组件要透出壁纸，
/// 垫厚白就成了贴在墙上的纸片。
///
/// 点击都能进去：今日进日历、心情进会话、在听进音乐。

// MARK: - 今日

/// 横跨四格。日程取「还没过去的两条」，全过完了就退成今天最后两条。
struct HomeTodayWidget: View {
    let schedule: DaySchedule?
    let action: () -> Void

    /// 跟图标名同一套规则：设置里选过白/黑就听设置，自动档跟着日夜。
    private var ink: Color { HomeWidgetInk.current }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 8)

                if let first = items.first {
                    row(first, strong: true)
                    if items.count > 1 {
                        row(items[1], strong: false)
                    }
                } else {
                    Text("今天还没排事")
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.55))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: HomeWidgetSize.tall)
            .frostedBar(cornerRadius: PhoneMetrics.Radius.widget, shadow: .none)
        }
        .buttonStyle(HomeWidgetPressStyle())
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("今天")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink)

            Text(TimeFormat.lockDate(Date()))
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.5))

            Spacer(minLength: 0)

            Text(remainingText)
                .font(.system(size: 10))
                .foregroundStyle(ink.opacity(0.42))
        }
    }

    private func row(_ item: ScheduleItem, strong: Bool) -> some View {
        HStack(spacing: 7) {
            Text(item.timeText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(ink.opacity(strong ? 0.7 : 0.42))

            Text(item.title)
                .font(.system(size: strong ? 13 : 12))
                .foregroundStyle(ink.opacity(strong ? 1 : 0.5))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    /// 还没到的先给；一条都不剩就退回今天最后两条，别让组件空着。
    private var items: [ScheduleItem] {
        guard let schedule, !schedule.items.isEmpty else { return [] }
        let hour = Calendar.current.component(.hour, from: Date())
        let upcoming = schedule.items.filter { $0.hour >= hour }.sorted { $0.hour < $1.hour }
        let source = upcoming.isEmpty
            ? schedule.items.sorted { $0.hour > $1.hour }.prefix(2)
            : upcoming.prefix(2)
        return Array(source)
    }

    private var remainingText: String {
        let total = schedule?.items.count ?? 0
        guard total > 0 else { return "" }
        let rest = total - items.count
        return rest > 0 ? "还有 \(rest) 条" : "\(total) 条"
    }
}

// MARK: - 心情

/// 两格方块。符号按心情换，底下补一句起因——只看「疲惫」不知道在累什么。
struct HomeMoodWidget: View {
    let mood: MoodState?
    /// 是谁的心情。多角色之后光写「他的心情」没人知道是哪个「他」。
    var owner: String = ""
    let action: () -> Void

    /// 跟图标名同一套规则：设置里选过白/黑就听设置，自动档跟着日夜。
    private var ink: Color { HomeWidgetInk.current }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: mood?.mood.symbol ?? "circle.dashed")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(ink.opacity(mood == nil ? 0.3 : 0.85))

                Spacer(minLength: 6)

                Text(mood?.mood.label ?? "还没定")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink.opacity(mood == nil ? 0.4 : 1))

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.5))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: HomeWidgetSize.square)
            .frostedBar(cornerRadius: PhoneMetrics.Radius.widget, shadow: .none)
        }
        .buttonStyle(HomeWidgetPressStyle())
    }

    private var subtitle: String {
        if let mood, !mood.reason.isEmpty { return mood.reason }
        return owner.isEmpty ? "他的心情" : "\(owner)的心情"
    }
}

// MARK: - 在听

/// 两格方块。没有歌在放就明说，不留一块假封面。
struct HomeMusicWidget: View {
    let track: Track?
    let playing: Bool
    /// 播放进度，0…1。组件上也能看出放到哪了。
    var progress: Double = 0
    let action: () -> Void

    /// 跟图标名同一套规则：设置里选过白/黑就听设置，自动档跟着日夜。
    private var ink: Color { HomeWidgetInk.current }

    /// 这首歌自己的颜色，和列表封面、歌词页的唱片是同一个。
    private var tint: Color { TrackArt.tint(for: track?.id ?? "") }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    if track == nil {
                        Image(systemName: "music.note")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ink.opacity(0.3))
                    } else {
                        // 一张小唱片占住上半块。原来这里只有一个音符图标，
                        // 整块看起来是一行文字贴在空卡上。
                        CompactDisc(size: 26, tint: tint, spinning: playing)
                    }

                    Spacer(minLength: 0)

                    if playing {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink.opacity(0.7))
                            .symbolEffect(.variableColor.iterative, isActive: playing)
                    }
                }

                Spacer(minLength: 8)

                Text(track?.title ?? "没有在放")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.opacity(track == nil ? 0.4 : 1))
                    .lineLimit(1)

                Text(track?.artist ?? "点开挑一首")
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.5))
                    .lineLimit(1)
                    .padding(.top, 2)

                progressLine
                    .padding(.top, 9)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: HomeWidgetSize.square)
            // 磨砂，不是 `glassSurface`。
            //
            // `glassEffect` 跟着外壳的配色方案走，而这台手机的外壳锁的是深色，
            // 整块玻璃就按深色材质渲染——压在粉色壁纸上是一个黑块，和上面那块
            // 「今天」完全是两种东西。那块用的是 `frostedBar`，明暗由
            // `FrostedSurface` 按日夜自己算，日间是透亮的白。两块改回同一套配方。
            .frostedBar(cornerRadius: PhoneMetrics.Radius.widget, shadow: .none)
        }
        .buttonStyle(HomeWidgetPressStyle())
    }

    private var progressLine: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ink.opacity(0.16))
                Capsule()
                    .fill(ink.opacity(track == nil ? 0.08 : 0.62))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 2.5)
    }
}

/// 组件上的字色。跟 `AppIconTile` 的图标名共用一套判断。
enum HomeWidgetInk {
    static var current: Color {
        HomeTextInk.current.explicitColor
            ?? (ThemeStore.shared.isNight ? .white : .black.opacity(0.86))
    }
}

// MARK: - 尺寸与按压

/// 组件的两个高度档。宽组件高一些，能放两行日程；方块放封面 + 两行字。
///
/// 方块从 112 提到 128：112 的时候音乐组件只装得下一行图标两行字，
/// 底下空一块，看着是「一条窄卡片」，不像一个能点的组件。
enum HomeWidgetSize {
    static let tall: CGFloat = 118
    static let square: CGFloat = 128
    /// 方块之间的缝，跟图标网格的横向间距对齐。
    static let gap: CGFloat = PhoneMetrics.gridHorizontalSpacing
}

/// 小组件按下时缩得比图标轻：它面积大，按 0.88 会像整块板子在动。
struct HomeWidgetPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
