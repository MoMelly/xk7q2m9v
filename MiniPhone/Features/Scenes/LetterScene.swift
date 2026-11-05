import SwiftUI

/// 信件。
///
/// 桌面上的「邮件」改名成信件：这里不收工作邮件，只收角色写来的信。
/// 结构照系统的信箱：一行一封，左边发信人、右边时间，未读用一个小红点。
struct LetterScene: View {
    let world: WorldStore
    let settings: SettingsStore
    var onClose: () -> Void

    private var letters: [Letter] {
        world.state.letters.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        AppScreen(title: "信件", surface: .light, onClose: onClose) {
            if letters.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(letters) { letter in
                            NavigationLink {
                                LetterReaderPage(letter: letter, world: world)
                            } label: {
                                row(letter)
                            }
                            .buttonStyle(.plain)

                            RowDivider()
                        }
                    }
                    .background(AppSurface.light.rowSurface)
                }
            }
        }
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
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "envelope.open")
                .font(.system(size: 30, weight: .light))
            Text("还没有收到信")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("在角色详情页里点「让 TA 写封信」，写好的信会放在这里。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.xl)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 读一封信。
///
/// 不用白卡套正文：信就该像纸，用米色底 + 衬线字，落款靠右。
struct LetterReaderPage: View {
    let letter: Letter
    let world: WorldStore

    var body: some View {
        AppPage(title: letter.title, surface: .light) {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                    HStack(spacing: PhoneMetrics.Space.xs) {
                        Text("来自 \(letter.fromName)")
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                            .foregroundStyle(AppSurface.light.secondaryLabel)

                        Spacer(minLength: 0)

                        Text(TimeFormat.monthDayTime(letter.createdAt))
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }

                    Text(letter.body)
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
        .onAppear { world.markLetterRead(letter.id) }
    }
}
