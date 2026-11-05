import SwiftUI

/// 购物。
///
/// 这里的真实数据只有订单，所以按订单列表来做：顶部一条汇总，下面按
/// 进行中 / 已完成分组。做一个假的商城首页没有意义——点进去没有商品详情，
/// 也没有支付，只会显得更假。
struct ShoppingScene: View {
    let world: WorldStore
    var onClose: () -> Void

    private var inProgress: [ShoppingItem] {
        world.state.shopping
            .filter { $0.status != "已送达" }
            .sorted { $0.orderedAt > $1.orderedAt }
    }

    private var finished: [ShoppingItem] {
        world.state.shopping
            .filter { $0.status == "已送达" }
            .sorted { $0.orderedAt > $1.orderedAt }
    }

    var body: some View {
        AppScreen(title: "购物", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    summary
                    if inProgress.isEmpty && finished.isEmpty {
                        emptyState
                    } else {
                        if !inProgress.isEmpty {
                            section(title: "进行中", items: inProgress)
                        }
                        if !finished.isEmpty {
                            section(title: "已完成", items: finished)
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("共 \(world.state.shopping.count) 笔")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.secondaryLabel)
                Text(totalPrice)
                    .font(.system(size: PhoneMetrics.FontSize.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.label)
            }
            Spacer()
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    /// 价格存的是「¥129」这种带符号的字符串，求和要先把非数字剔掉。
    private var totalPrice: String {
        let total = world.state.shopping.reduce(0) { sum, item in
            sum + (Int(item.price.filter(\.isNumber)) ?? 0)
        }
        return "¥\(total)"
    }

    private func section(title: String, items: [ShoppingItem]) -> some View {
        GroupedSection(
            title,
            footer: title == "进行中" ? "本地清单，不涉及支付，也不会真的下单。" : nil
        ) {
            ForEach(items) { item in
                HStack(spacing: PhoneMetrics.Space.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(Theme.label)
                            .lineLimit(1)
                        Text("\(item.price) · \(TimeFormat.callTime(item.orderedAt))")
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                    }

                    Spacer(minLength: PhoneMetrics.Space.xs)

                    Text(item.status)
                        .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                        .foregroundStyle(item.status == "已送达" ? Theme.secondaryLabel : Theme.IconTint.orange)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)

                if item.id != items.last?.id {
                    RowDivider()
                }
            }
        }
    }

    private var emptyState: some View {
        Text("还没有订单")
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PhoneMetrics.Space.m)
    }
}
