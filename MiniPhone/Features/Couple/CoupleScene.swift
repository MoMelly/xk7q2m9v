import SwiftUI
import SwiftData

/// 情侣空间。
///
/// 只有一件事：火花。数字是连续天数，两个人都开过口才算一天。
/// 不做签到按钮——真按一下就能加一天，这个数字就没有意义了；
/// 想续火花只有一条路，去跟他说句话。
///
/// 火花按角色各算一份：跟 A 说过话不该出现在跟 B 的火花里。
/// 顶部那排名字就是切开这件事的开关。
///
/// 视觉上是一块大号液态玻璃：磨砂透出壁纸、左上角一层玫瑰色柔光、字走墨色。
/// 上一版是一整块橙红渐变加白字，颜色太吵，像活动横幅而不是一件私人的东西。
struct CoupleScene: View {
    let world: WorldStore
    var initialOwner: String? = nil
    var onClose: () -> Void

    @Query(sort: \Companion.sortIndex) private var companions: [Companion]
    @State private var selectedName: String?

    /// 有火花的候选人。西瓜皮的路人作者和内置小助手不算。
    private var candidates: [Companion] {
        companions.filter { !$0.isFeedOnly && $0.name != DefaultAssistant.name }
    }

    private var recentOwner: Companion? {
        candidates
            .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
            .first
    }

    private var partner: Companion? {
        let wanted = selectedName ?? initialOwner
        if let wanted, let hit = candidates.first(where: { $0.name == wanted }) {
            return hit
        }
        return recentOwner
    }

    private var partnerName: String { partner?.name ?? "" }

    private var state: CoupleState { world.coupleState(for: partnerName) }
    private var streak: Int { CoupleEngine.streak(state) }
    private var best: Int { CoupleEngine.best(state) }
    private var activeToday: Bool { CoupleEngine.isActiveToday(state) }
    private var onlyMine: Bool { CoupleEngine.onlyMineToday(state) }
    private var recent: [(key: String, active: Bool)] { CoupleEngine.recent(state, days: 14) }

    var body: some View {
        AppScreen(title: "情侣空间", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    NameChipStrip(
                        names: candidates.map(\.name),
                        selected: Binding(
                            get: { partnerName },
                            set: { selectedName = $0 }
                        )
                    )

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
        VStack(alignment: .leading, spacing: 0) {
            header

            HStack(alignment: .center, spacing: 14) {
                flameBadge

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(streak)")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.label)
                            .contentTransition(.numericText())

                        Text("天")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.secondaryLabel)
                    }

                    Text(statusLine)
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(Theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 10)

            recentStrip
                .padding(.top, 16)
        }
        .padding(PhoneMetrics.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 柔光贴着内容铺，磨砂在它下面：这样玻璃还是玻璃，
            // 只是整体偏一点玫瑰，不是把整块染成粉色。
            RadialGradient(
                colors: [Theme.IconTint.rose.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 6,
                endRadius: 280
            )
        }
        .frostedCard(cornerRadius: PhoneMetrics.Radius.glass)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("连着说上话")
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(Theme.secondaryLabel)

            Spacer(minLength: 0)

            Text(dayCountText)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.8))
        }
    }

    /// 火苗装在一颗淡玫瑰的圆里，比直接放大一个图标更像一个标记。
    private var flameBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.IconTint.rose.opacity(streak > 0 ? 0.16 : 0.08))
                .frame(width: 58, height: 58)

            Image(systemName: "flame.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.IconTint.rose)
                .opacity(streak > 0 ? 1 : 0.4)
        }
    }

    /// 最近 14 天，一天一根竖条。今天在最右。
    private var recentStrip: some View {
        HStack(spacing: 5) {
            ForEach(recent, id: \.key) { day in
                Capsule()
                    .fill(day.active ? Theme.IconTint.rose.opacity(0.9) : Theme.separator.opacity(0.42))
                    .frame(height: day.key == recent.last?.key ? 10 : 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 10, alignment: .center)
        .accessibilityLabel("最近 14 天里说上话的有 \(recent.filter { $0.active }.count) 天")
    }

    /// 三种状态说三种话。今天还没结束时不能说「断了」。
    private var statusLine: String {
        guard !partnerName.isEmpty else { return "先在信息里建一个角色，才有火花可算" }
        if activeToday { return "今天已经续上了" }
        if onlyMine { return "你说过了，等他也开口" }
        if streak > 0 { return "今天还没说话，火花等在这儿" }
        return "说一句话，就是第一天"
    }

    /// 「第 41 天」：从关系起算那天到今天，含头含尾。
    private var dayCountText: String {
        guard let key = state.sinceKey, let start = TimeFormat.date(fromKey: key) else { return "还没开始" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return "第 \(days + 1) 天"
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
                        .fill(day.active ? Theme.IconTint.rose.opacity(0.85) : Theme.separator.opacity(0.5))
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
            statRow("一起的第", value: dayCountText.replacingOccurrences(of: "第 ", with: ""))
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

    private var footnote: some View {
        Text("火花按天算：两个人都说过话才算一天。\n哪天没续上就归零，从新的一天重新开始——所以它才值钱。")
            .font(.system(size: PhoneMetrics.FontSize.caption))
            .foregroundStyle(Theme.secondaryLabel)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
