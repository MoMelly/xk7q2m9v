import SwiftUI

/// 西瓜皮里的「市集」。
///
/// 原来是一个独立 App，合并后这一层不套 AppScreen、也不放第二套底栏：
/// 外层 FeedScene 已经有五格导航，再叠一层会把内容区挤没。
/// 购物车、订单、我的收成顶部一排小分段，刷新统一走右上角那个箭头。
struct MarketView: View {
    let world: WorldStore

    @State private var section: Section = .browse
    @State private var category: String?

    enum Section: String, CaseIterable, Identifiable {
        case browse = "逛逛"
        case cart = "购物车"
        case orders = "订单"
        case mine = "我的"

        var id: String { rawValue }
    }

    private var items: [ShopItem] {
        guard let category else { return world.state.shop }
        return world.state.shop.filter { $0.category == category }
    }

    private var categories: [String] {
        var seen: [String] = []
        for item in world.state.shop where !item.category.isEmpty && !seen.contains(item.category) {
            seen.append(item.category)
        }
        return Array(seen.prefix(5))
    }

    private var cartItems: [ShopItem] {
        world.state.shop.filter(\.inCart)
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionRow

            switch section {
            case .browse: browse
            case .cart: cartPage
            case .orders: ordersPage
            case .mine: minePage
            }
        }
    }

    private var sectionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                ForEach(Section.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(
                                size: PhoneMetrics.FontSize.footnote,
                                weight: section == item ? .semibold : .regular
                            ))
                            .foregroundStyle(section == item ? .white : AppSurface.light.label)
                            .padding(.horizontal, PhoneMetrics.Space.s)
                            .frame(height: 26)
                            .background(
                                Capsule().fill(
                                    section == item ? Theme.brand : AppSurface.light.rowSurface
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
        }
        .padding(.vertical, PhoneMetrics.Space.xs)
    }

    // MARK: - 逛逛

    private var browse: some View {
        VStack(spacing: 0) {
            searchBar
            if !categories.isEmpty {
                categoryRow
            }

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: PhoneMetrics.Space.xs),
                            GridItem(.flexible(), spacing: PhoneMetrics.Space.xs)
                        ],
                        spacing: PhoneMetrics.Space.s
                    ) {
                        ForEach(items) { item in
                            productCard(item)
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.s)
                    .padding(.top, PhoneMetrics.Space.xs)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
            Text("你想要什么")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .padding(.horizontal, PhoneMetrics.Space.s)
        .frame(height: 34)
        .background(Capsule().fill(AppSurface.light.rowSurface))
        .overlay(Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.5))
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.xxs)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                chip("全部", active: category == nil) { category = nil }
                ForEach(categories, id: \.self) { name in
                    chip(name, active: category == name) { category = name }
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
        }
        .padding(.vertical, PhoneMetrics.Space.xs)
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? .white : AppSurface.light.label)
                .padding(.horizontal, PhoneMetrics.Space.s)
                .frame(height: 26)
                .background(
                    Capsule().fill(active ? Theme.brand : AppSurface.light.rowSurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func productCard(_ item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                ProductThumb(title: item.title, seed: item.imageSeed)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))

                Button {
                    world.setCart(itemID: item.id, inCart: !item.inCart)
                } label: {
                    Image(systemName: item.inCart ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                item.inCart ? Theme.IconTint.green : Theme.brand
                            )
                        )
                }
                .buttonStyle(.plain)
                .padding(6)
            }

            Text(item.title)
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 6)

            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(item.priceText)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .bold))
                    .foregroundStyle(Theme.price)
                Spacer(minLength: 0)
            }
            .padding(.top, 4)

            if !item.reason.isEmpty {
                Text("因为你说「\(item.reason)」")
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.8))
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, PhoneMetrics.Space.xs)
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "bag")
                .font(.system(size: 26))
            Text("还没有推荐")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
            Text("聊聊你最近缺什么、想要什么，这里会跟着变。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PhoneMetrics.Space.l)
    }

    // MARK: - 购物车

    private var cartPage: some View {
        Group {
            if cartItems.isEmpty {
                emptyState(text: "购物车是空的", detail: "在商品右下角点加号放进来。")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(cartItems) { item in
                            HStack(spacing: PhoneMetrics.Space.s) {
                                ProductThumb(title: item.title, seed: item.imageSeed)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.cover, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: PhoneMetrics.FontSize.sub))
                                        .foregroundStyle(AppSurface.light.label)
                                        .lineLimit(1)
                                    Text(item.priceText)
                                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                                        .foregroundStyle(Theme.price)
                                }

                                Spacer(minLength: 0)

                                Button("移出") {
                                    world.setCart(itemID: item.id, inCart: false)
                                }
                                .font(.system(size: PhoneMetrics.FontSize.footnote))
                                .foregroundStyle(AppSurface.light.secondaryLabel)
                            }
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: 72)

                            RowDivider()
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.xs)
                }
            }
        }
    }

    // MARK: - 订单

    private var ordersPage: some View {
        Group {
            if world.state.shopping.isEmpty {
                emptyState(text: "还没有订单", detail: "这里放真下过单的东西，现在只是本地清单。")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(world.state.shopping) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: PhoneMetrics.FontSize.body))
                                        .foregroundStyle(AppSurface.light.label)
                                    Text("\(item.price) · \(TimeFormat.callTime(item.orderedAt))")
                                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                                        .foregroundStyle(AppSurface.light.secondaryLabel)
                                }
                                Spacer(minLength: 0)
                                Text(item.status)
                                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                                    .foregroundStyle(AppSurface.light.secondaryLabel)
                            }
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: PhoneMetrics.Row.detailed)

                            RowDivider()
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.xs)
                }
            }
        }
    }

    // MARK: - 我的

    private var minePage: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(world.state.shop.count) 件推荐")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                    Text("\(cartItems.count) 件在购物车")
                        .font(.system(size: PhoneMetrics.FontSize.largeTitle, weight: .bold))
                        .foregroundStyle(AppSurface.light.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PhoneMetrics.Space.m)

                GroupedSection(footer: "推荐来自你跟角色的对话，不会上传到任何地方。") {
                    GroupedRow(title: "推荐来源", value: "聊天内容")
                    RowDivider()
                    GroupedRow(title: "结算", value: "暂不支持")
                }
            }
            .padding(.top, PhoneMetrics.Space.s)
        }
    }

    private func emptyState(text: String, detail: String) -> some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Text(text)
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
            Text(detail)
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PhoneMetrics.Space.l)
    }
}
