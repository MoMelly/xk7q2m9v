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
        AppScreen(title: "信件", surface: .light, onClose: onClose) {
            VStack(spacing: 0) {
                SegmentedTabs(items: Filter.allCases, title: { $0.title }, selection: $filter)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.top, PhoneMetrics.Space.xs)
                    .padding(.bottom, PhoneMetrics.Space.s)

                if letters.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
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

                                RowDivider()
                            }
                        }
                        .background(AppSurface.light.rowSurface)
                    }
                }
            }
        }
        .onAppear { seedTrialLetterIfNeeded() }
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(letter.isFavorite ? Theme.warning : AppSurface.light.secondaryLabel.opacity(0.55))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(letter.isFavorite ? "取消收藏" : "收藏")
    }

    private func row(_ letter: Letter) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            ZStack {
                Circle()
                    .fill(Theme.Watermelon.pith)
                Text(String(letter.fromName.prefix(1)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.deepGreen)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PhoneMetrics.Space.xxs) {
                    Text(letter.fromName)
                        .font(.system(
                            size: PhoneMetrics.FontSize.footnote,
                            weight: letter.isRead ? .regular : .semibold
                        ))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)

                    if !letter.isRead {
                        Circle()
                            .fill(Theme.brand)
                            .frame(width: 6, height: 6)
                    }

                    Spacer(minLength: 0)

                    Text(TimeFormat.callTime(letter.createdAt))
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }

                Text(letter.title)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: letter.isRead ? .regular : .semibold))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(1)

                Text(letter.body.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(2)
            }
        }
        .padding(.leading, PhoneMetrics.Space.m)
        .padding(.trailing, PhoneMetrics.Space.xxs)
        .padding(.vertical, PhoneMetrics.Space.s)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: filter == .favorite ? "star" : "envelope.open")
                .font(.system(size: 30, weight: .light))

            Text(emptyTitle)
                .font(.system(size: PhoneMetrics.FontSize.sub))

            Text(emptyHint)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.xl)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
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
/// 不用白卡套正文：信就该像纸，用米色底 + 衬线字，落款靠右。
struct LetterReaderPage: View {
    let letter: Letter
    let world: WorldStore

    /// 从世界里读最新的一份：收藏状态改了要立刻反映到那颗星上。
    private var current: Letter {
        world.state.letters.first(where: { $0.id == letter.id }) ?? letter
    }

    var body: some View {
        AppPage(title: current.title, surface: .light) {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                    HStack(spacing: PhoneMetrics.Space.xs) {
                        Text("来自 \(current.fromName)")
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                            .foregroundStyle(AppSurface.light.secondaryLabel)

                        Spacer(minLength: 0)

                        Text(TimeFormat.monthDayTime(current.createdAt))
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }

                    Text(current.body)
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(AppSurface.light.label)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(PhoneMetrics.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cream)
                .clipShape(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                )
                .padding(PhoneMetrics.Space.m)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    world.toggleLetterFavorite(current.id)
                } label: {
                    Image(systemName: current.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(current.isFavorite ? Theme.warning : Theme.secondaryLabel)
                }
                .accessibilityLabel(current.isFavorite ? "取消收藏" : "收藏")
            }
        }
        .onAppear { world.markLetterRead(letter.id) }
    }
}
