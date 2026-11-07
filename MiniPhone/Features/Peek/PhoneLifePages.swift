import SwiftUI

/// 购物清单。
///
/// 这是他自己在买的东西，往往能看出下一步要干什么 —— 护手霜、台灯、猫抓板。
/// 状态用一个小胶囊标出来，不用图标：状态本来就三个词，图标反而要看图例。
struct PhoneShoppingPage: View {
    let phone: CharacterPhone

    var body: some View {
        AppPage(title: "购物", surface: .light) {
            ScrollView {
                GroupedSection("\(phone.shopping.count) 件") {
                    ForEach(phone.shopping) { item in
                        row(item)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)

                Text("购物卡里的东西不一定买得成。想让他知道你看过，回去问一句。")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.top, PhoneMetrics.Space.s)
                    .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func row(_ item: PhoneShopping) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(2)

                Text(item.addedAt)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.75))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 5) {
                Text(item.price)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)

                Text(item.status)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.groupedBackground))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
    }
}

/// 浏览记录。
///
/// 这个板块最好看：一个人搜什么，比他嘴上说什么诚实。
/// 所以按时间倒序，不加分组不加筛选 —— 一屏看下去就是他那一天。
struct PhoneBrowsePage: View {
    let phone: CharacterPhone

    var body: some View {
        AppPage(title: "浏览器", surface: .light) {
            ScrollView {
                GroupedSection("最近 \(phone.history.count) 条") {
                    ForEach(phone.history) { entry in
                        row(entry)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func row(_ entry: PhoneBrowse) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(2)
                Text(entry.site)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Spacer(minLength: 0)

            Text(entry.time)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
    }
}

/// 屏幕时间。
///
/// 上面一条总时长，下面按 App 排。条的长度是相对最长那个算的，
/// 不是相对一天 —— 相对一天的话所有条都会很短，看不出差别。
struct PhoneUsagePage: View {
    let phone: CharacterPhone

    private var total: Int { phone.usage.reduce(0) { $0 + $1.minutes } }
    private var longest: Int { max(phone.usage.map(\.minutes).max() ?? 1, 1) }

    var body: some View {
        AppPage(title: "屏幕时间", surface: .light) {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
                    Text("今天 \(total / 60) 小时 \(total % 60) 分")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(AppSurface.light.label)
                    Text("比昨天少一点" )
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PhoneMetrics.Space.m)

                GroupedSection("按 App") {
                    ForEach(phone.usage) { item in
                        row(item)
                    }
                }
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func row(_ item: PhoneUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.app)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                Spacer(minLength: 0)
                Text(item.display)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.groupedBackground)
                    Capsule()
                        .fill(Theme.IconTint.gray.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * CGFloat(item.minutes) / CGFloat(longest)))
                }
            }
            .frame(height: 6)

            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
    }
}

/// 他没说出口的事。
///
/// 分两档：「瞒着你」默认就能看，「私密」要在设置里打开才展开。
/// 挡一道不是为了吊胃口，是因为翻到这一档就不是「看手机」，是另一件事了。
struct PhoneSecretsPage: View {
    let phone: CharacterPhone
    let unlocked: Bool

    private var secrets: [PhoneSecret] { phone.secrets.filter { !$0.isPrivate } }
    private var privateOnes: [PhoneSecret] { phone.secrets.filter(\.isPrivate) }

    var body: some View {
        AppPage(title: "私密", surface: .light) {
            ScrollView {
                if !secrets.isEmpty {
                    GroupedSection("瞒着你 \(secrets.count) 条") {
                        ForEach(secrets) { item in
                            row(item)
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.s)
                }

                if secrets.isEmpty && privateOnes.isEmpty {
                    Text("这一次他身上没什么瞒着的。")
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }

                privateSection
                    .padding(.top, PhoneMetrics.Space.m)

                Text("看过之后要不要提，你自己决定。提了，他会知道你看过。")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineSpacing(3)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.top, PhoneMetrics.Space.s)
                    .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    @ViewBuilder
    private var privateSection: some View {
        if unlocked {
            if !privateOnes.isEmpty {
                GroupedSection("私密 \(privateOnes.count) 条", footer: "这一档只有你们两个人。") {
                    ForEach(privateOnes) { item in
                        row(item)
                    }
                }
            }
        } else {
            GroupedSection("私密", footer: "设置 → 行为 → 允许看私密这一档。默认关。") {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                    Text("有一档锁着，\(privateOnes.count) 条")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    private func row(_ item: PhoneSecret) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)
                Spacer(minLength: 0)
                Text(item.time)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Text(item.text)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label.opacity(0.9))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
    }
}
