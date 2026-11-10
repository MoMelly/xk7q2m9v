import SwiftUI

/// 信件。
///
/// 桌面上的「邮件」改名成信件：这里不收工作邮件，只收角色写来的信。
/// 结构照系统的信箱：一行一封，左边发信人、右边时间，未读用一个小红点。
/// 顶上一排分类（全部 / 未读 / 收藏），行尾一颗星直接收。
struct LetterScene: View {
    let world: WorldStore
    let settings: SettingsStore
    var onClose: () -> Void

    @State private var filter: Filter = .all

    /// 三档分类。不做「按角色筛」：信本来就不多，一屏能看完，
    /// 多一层筛选等于多一次点击。
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case unread
        case favorite

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "全部"
            case .unread: return "未读"
            case .favorite: return "收藏"
            }
        }
    }

    private var allLetters: [Letter] {
        world.state.letters.sorted { $0.createdAt > $1.createdAt }
    }

    private var letters: [Letter] {
        switch filter {
        case .all:
            return allLetters
        case .unread:
            return allLetters.filter { !$0.isRead }
        case .favorite:
            return allLetters.filter { $0.isFavorite }
        }
    }

    var body: some View {
        AppScreen(title: "信件", surface: .paper, onClose: onClose) {
            VStack(spacing: 0) {
                filterBar

                if letters.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(letters) { letter in
                                HStack(spacing: 0) {
                                    NavigationLink {
                                        LetterReaderPage(letter: letter, world: world)
                                    } label: {
                                        row(letter)
                                    }
                                    .buttonStyle(.plain)

                                    starButton(letter)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                        .fill(Theme.StoryPaper.card)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                        .strokeBorder(Theme.StoryPaper.rule.opacity(0.7), lineWidth: 0.8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 26)
                    }
                }
            }
        }
        .onAppear { seedTrialLetterIfNeeded() }
    }

    /// 三档筛选画成书页页边的下划线，不用分段控件。
    ///
    /// 分段控件是一整块灰底滑块，压在纸上会像贴了一张便签纸；
    /// 一条细下划线更接近目录的写法，也不用额外解释哪一档被选中了。
    private var filterBar: some View {
        HStack(spacing: 20) {
            ForEach(Filter.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { filter = item }
                } label: {
                    VStack(spacing: 5) {
                        Text(item.title)
                            .font(Theme.serif(14, weight: filter == item ? .semibold : .regular))
                            .foregroundStyle(
                                filter == item
                                    ? Theme.StoryPaper.ink
                                    : Theme.StoryPaper.inkSoft.opacity(0.85)
                            )

                        Rectangle()
                            .fill(filter == item ? Theme.StoryPaper.vermilion : Color.clear)
                            .frame(height: 1.5)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    /// 首次进信件页给一封小助手的信：先让她看到信长什么样、能读能收，
    /// 不然空信箱和没做没区别。只种一次，删不掉是另一回事。
    private func seedTrialLetterIfNeeded() {
        let key = "letters.seededTrial"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        world.appendLetter(
            from: "小助手",
            title: "欢迎来到这台手机",
            body: """
            见字如面。

            我是住在这台手机里的小助手。你刚搬进来，有些事我先跟你说一声：信息页可以随时找我聊天，日历和备忘录你自己管，西瓜皮是大家写动态的地方——写完记得给我看一眼。

            往后我会不定期给你写信：有时候是发生了什么有意思的事，有时候只是想跟你说说话。看到信角上有小红点，就是我有新话要讲。

            就先写到这里。回不回都行，我知道你在忙。

            ——小助手
            """
        )
    }

    /// 行尾那颗星。收藏和已读是两件事，点星不改未读状态。
    private func starButton(_ letter: Letter) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                world.toggleLetterFavorite(letter.id)
            }
        } label: {
            Image(systemName: letter.isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    letter.isFavorite
                        ? Theme.StoryPaper.vermilion
                        : Theme.StoryPaper.inkSoft.opacity(0.4)
                )
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(letter.isFavorite ? "取消收藏" : "收藏")
    }

    private func row(_ letter: Letter) -> some View {
        HStack(alignment: .top, spacing: 11) {
            // 一枚小小的朱红印章，替掉原来的圆形头像块。
            // 信上本来不该有头像——那是聊天列表的写法。
            ZStack {
                Circle()
                    .strokeBorder(Theme.StoryPaper.vermilion.opacity(0.45), lineWidth: 0.9)
                Text(String(letter.fromName.prefix(1)))
                    .font(Theme.serif(13, weight: .semibold))
                    .foregroundStyle(Theme.StoryPaper.vermilion)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(letter.fromName)
                        .font(Theme.serif(12, weight: letter.isRead ? .regular : .semibold))
                        .foregroundStyle(Theme.StoryPaper.inkSoft)
                        .lineLimit(1)

                    if !letter.isRead {
                        Circle()
                            .fill(Theme.StoryPaper.vermilion)
                            .frame(width: 5, height: 5)
                    }

                    Spacer(minLength: 0)

                    Text(TimeFormat.callTime(letter.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.StoryPaper.inkSoft.opacity(0.7))
                }

                Text(letter.title)
                    .font(Theme.serif(15, weight: letter.isRead ? .regular : .semibold))
                    .foregroundStyle(Theme.StoryPaper.ink)
                    .lineLimit(1)

                Text(letter.body.replacingOccurrences(of: "\n", with: " "))
                    .font(Theme.serif(11.5))
                    .foregroundStyle(Theme.StoryPaper.inkSoft)
                    .lineLimit(2)
                    .lineSpacing(3)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("❖")
                .font(.system(size: 15))
                .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.5))

            Text(emptyTitle)
                .font(Theme.serif(15, weight: .medium))
                .foregroundStyle(Theme.StoryPaper.ink)

            Text(emptyHint)
                .font(Theme.serif(11.5))
                .foregroundStyle(Theme.StoryPaper.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, PhoneMetrics.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        switch filter {
        case .all: return "还没有收到信"
        case .unread: return "都读完了"
        case .favorite: return "还没有收藏的信"
        }
    }

    private var emptyHint: String {
        switch filter {
        case .all:
            return "在角色详情页里点「让 TA 写封信」，写好的信会放在这里。"
        case .unread:
            return "读过的信在「全部」里。"
        case .favorite:
            return "点每行右边那颗星，就能把信收起来。"
        }
    }
}

/// 读一封信。
///
/// 整页就是一张纸，不再往灰底上摆一张米色卡——
/// 灰底上的米色卡看着像「一张便签贴在墙上」，而这里要的是「摊开一封信」。
struct LetterReaderPage: View {
    let letter: Letter
    let world: WorldStore

    /// 从世界里读最新的一份：收藏状态改了要立刻反映到那颗星上。
    private var current: Letter {
        world.state.letters.first(where: { $0.id == letter.id }) ?? letter
    }

    var body: some View {
        AppPage(title: current.title, surface: .paper) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    head

                    Text(current.body)
                        .font(Theme.serif(15.5))
                        .foregroundStyle(Theme.StoryPaper.ink)
                        .lineSpacing(9)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    world.toggleLetterFavorite(current.id)
                } label: {
                    Image(systemName: current.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(
                            current.isFavorite
                                ? Theme.StoryPaper.vermilion
                                : Theme.StoryPaper.inkSoft.opacity(0.6)
                        )
                }
                .accessibilityLabel(current.isFavorite ? "取消收藏" : "收藏")
            }
        }
        .onAppear { world.markLetterRead(letter.id) }
    }

    /// 抬头：谁写来的、什么时候写的，下面压一条细线。
    private var head: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("来自 \(current.fromName)")
                .font(.system(size: 10, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Theme.StoryPaper.vermilion)

            Text(TimeFormat.monthDayTime(current.createdAt))
                .font(.system(size: 10))
                .foregroundStyle(Theme.StoryPaper.inkSoft.opacity(0.75))

            LinearGradient(
                colors: [
                    Theme.StoryPaper.rule.opacity(0.9),
                    Theme.StoryPaper.rule.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.8)
            .padding(.top, 7)
        }
    }
}
