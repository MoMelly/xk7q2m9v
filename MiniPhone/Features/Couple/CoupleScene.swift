import SwiftUI

/// 情侣空间。
///
/// 只有一件事：火花。数字是连续天数，两个人都开过口才算一天。
/// 不做签到按钮——真按一下就能加一天，这个数字就没有意义了；
/// 想续火花只有一条路，去跟他说句话。
struct CoupleScene: View {
    let world: WorldStore
    var onClose: () -> Void

    private var state: CoupleState { world.state.couple }
    private var streak: Int { CoupleEngine.streak(state) }
    private var best: Int { CoupleEngine.best(state) }
    private var activeToday: Bool { CoupleEngine.isActiveToday(state) }
    private var onlyMine: Bool { CoupleEngine.onlyMineToday(state) }

    var body: some View {
        AppScreen(title: "情侣空间", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    sparkCard
                    heatmap
                    stats
                    footnote
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    // MARK: - 火花

    private var sparkCard: some View {
        VStack(spacing: 2) {
            // 不用脉冲：那张截图正好抓到淡出的帧，火焰只剩一团白雾。
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .opacity(streak > 0 ? 1 : 0.3)

            Text("\(streak)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("天").font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))

            Text(statusLine)
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.l)
        .background {
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.widget, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.IconTint.orange, Theme.IconTint.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.widget, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
        }
    }

    /// 三种状态说三种话。今天还没结束时不能说「断了」。
    private var statusLine: String {
        if activeToday { return "今天已经续上了" }
        if onlyMine { return "你说过了，等他也开口" }
        if streak > 0 { return "今天还没说话，火花等在这儿" }
        return "说一句话，就是第一天"
    }

    // MARK: - 热力图

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text("最近 30 天")
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.leading, 2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10),
                spacing: 4
            ) {
                ForEach(CoupleEngine.recent(state, days: 30), id: \.key) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(day.active ? Theme.IconTint.pink.opacity(0.9) : Theme.separator.opacity(0.5))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(PhoneMetrics.Space.s)
            .background {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(Theme.rowSurface)
            }
        }
    }

    // MARK: - 统计

    private var stats: some View {
        VStack(spacing: 0) {
            statRow("最长连续", value: "\(best) 天")
            RowDivider()
            statRow("一起的第", value: dayCountText)
            RowDivider()
            statRow("聊过的天数", value: "\(state.activeDays.count) 天")
        }
        .background {
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .fill(Theme.rowSurface)
        }
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(height: 44)
    }

    /// 「第 41 天」：从关系起算那天到今天，含头含尾。
    private var dayCountText: String {
        guard let key = state.sinceKey, let start = TimeFormat.date(fromKey: key) else { return "还没开始" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return "\(days + 1) 天"
    }

    private var footnote: some View {
        Text("火花按天算：两个人都说过话才算一天。\n哪天没续上就归零，从新的一天重新开始——所以它才值钱。")
            .font(.system(size: PhoneMetrics.FontSize.caption))
            .foregroundStyle(Theme.secondaryLabel)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
