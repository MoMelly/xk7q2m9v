import SwiftUI

/// 角色看板：一张大肖像，加上他此刻的状态。
///
/// 说清楚这一版是什么：**不是 Live2D**。手里只有一张方头像，没有分层立绘素材，
/// 硬画一个会动的身体只会更假。这里做的是把头像立起来——铺满一整块、
/// 底边渐隐、呼吸起伏、点一下有反应。观感上接近乙游的看板位，
/// 素材换成分层立绘之后，这一层不用重写。
struct CharacterBoardPage: View {
    let character: Companion
    let world: WorldStore

    /// 点出来的那句话。
    @State private var reaction: String?
    /// 点的次数。台词池按它轮，避免连点两次出同一句。
    @State private var pokeCount = 0
    /// 被戳的反应动作。
    @State private var nudged = false
    @State private var breathing = false

    private var mood: MoodState? { world.mood(for: character.name) }
    private var today: DaySchedule? { world.todaySchedule(for: character.name) }

    var body: some View {
        AppPage(title: "看板") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    portrait
                    statusGrid
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    // MARK: - 肖像

    private var portrait: some View {
        ZStack(alignment: .bottom) {
            backdrop

            // 立绘本体。头像图铺满、底边渐隐进背景，看起来像站在光里而不是贴了张图。
            Group {
                if let photo = character.avatarPhoto {
                    // 原来只有一层 `scaledToFill` + 固定 380 高 + `clipped()`：
                    // 尺寸跟这一块对不上的图会被切掉一截，横图切上下、竖图切两侧，
                    // 脸落在框外的就是一张没头的立绘。现在整张放进去（`scaledToFit`），
                    // 两侧空出来的地方垫同一张图的模糊副本，不露底色。
                    ZStack {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 28)
                            .opacity(0.5)

                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    fallbackFigure
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scaleEffect(breathing ? 1.03 : 1.0, anchor: .bottom)
            .offset(y: nudged ? -8 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: nudged)

            caption
        }
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.widget, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { poke() }
        .overlay(alignment: .top) {
            if let reaction {
                reactionBubble(reaction)
                    .padding(.top, PhoneMetrics.Space.s)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    /// 心情色做底，两团光拉开纵深。没有素材的时候，这一层就是「立绘」的全部氛围。
    private var backdrop: some View {
        ZStack {
            // 原来这层跟着心情色走，心情是「平静」的时候整块是墨绿。
            // 看板上要看的是人，底色一带颜色就抢——这里统一压到黑，
            // 明暗只靠上面两团光撑。
            LinearGradient(
                colors: [Color(white: 0.16), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -70, y: -110)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 80, y: -40)
        }
    }

    /// 没有头像图时的替身：一个首字加一圈光。
    private var fallbackFigure: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 240, height: 240)

            Text(character.avatarInitial)
                .font(.system(size: 96, weight: .light, design: .serif))
                .foregroundStyle(Color.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(character.name)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                if let mood {
                    Text(mood.mood.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }

                if let next = nextEvent {
                    Text("\(next.timeText) \(next.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.m)
    }

    private var nextEvent: ScheduleItem? {
        let hour = CharacterClock.calendar.component(.hour, from: Date())
        return today?.items.first { $0.hour >= hour } ?? today?.items.last
    }

    private func reactionBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.label)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, PhoneMetrics.Space.s)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, PhoneMetrics.Space.l)
    }

    // MARK: - 状态

    private var statusGrid: some View {
        GroupedSection("此刻") {
            GroupedRow(
                symbol: "face.smiling",
                symbolTint: MoodColor.of(mood?.mood ?? .calm),
                title: "心情",
                subtitle: mood?.reason.isEmpty == false ? mood?.reason : nil,
                value: mood?.mood.label ?? "还没定"
            )
            RowDivider()
            GroupedRow(
                symbol: "location.fill",
                symbolTint: Theme.IconTint.teal,
                title: "在哪",
                value: world.location(for: character.name).isEmpty
                    ? "没写过"
                    : world.location(for: character.name)
            )
            RowDivider()
            GroupedRow(
                symbol: "music.note",
                symbolTint: Theme.IconTint.pink,
                title: "在听",
                value: world.state.currentTrack?.title ?? "没在放"
            )
            RowDivider()
            GroupedRow(
                symbol: "heart.fill",
                symbolTint: Theme.IconTint.rose,
                title: "关系",
                value: AffinityScale.stage(of: world.affinity(for: character.name)).label
            )
        }
    }

    // MARK: - 点一下

    /// 点击反应。
    ///
    /// 台词优先从他真说过的话里挑——比预设的几句「干嘛」更像这个人。
    /// 一句都没有（刚建的角色）才回落到按心情分的池子。
    private func poke() {
        pokeCount += 1

        let lines = character.messages
            .filter { $0.role == .assistant && !$0.isRecalled && !$0.text.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(24)
            .map { SpeechService.spokenForm(of: $0.text) }
            .filter { !$0.isEmpty }

        let pool = lines.isEmpty ? Self.fallbackLines(mood: mood?.mood) : lines
        let picked = pool[pokeCount % max(pool.count, 1)]

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            nudged = true
            reaction = picked
        }

        Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            nudged = false
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                if reaction == picked { reaction = nil }
            }
        }
    }

    private static func fallbackLines(mood: Mood?) -> [String] {
        switch mood {
        case .tired, .low:
            return ["……嗯？", "让我缓缓。", "别闹，困。"]
        case .annoyed:
            return ["干嘛。", "你戳我干什么。", "有话直说。"]
        case .glad, .excited:
            return ["嗯？", "在呢。", "怎么了，想我了？"]
        default:
            return ["……", "在。", "嗯，你说。"]
        }
    }
}
