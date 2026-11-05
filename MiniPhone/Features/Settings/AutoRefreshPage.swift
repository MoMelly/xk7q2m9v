import SwiftUI

/// 自动刷新设置。
///
/// 每个页面各自一行：开关 + 概率。间隔是共用的——「攒够几轮才开始掷骰子」这件事
/// 对所有页面是同一个节奏，分开调只会让人算不清它什么时候变。
struct AutoRefreshPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        AppPage(title: "自动刷新") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    intervalSection
                    rulesSection
                    billingNote
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var intervalSection: some View {
        GroupedSection(
            footer: "每聊满这么多轮才掷一次骰子。掷中了就往对应页面里加新内容，没掷中继续攒。"
        ) {
            HStack(spacing: PhoneMetrics.Space.s) {
                Text("间隔")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)

                Stepper(value: intervalBinding, in: 2...30) {
                    Text("\(settings.refreshInterval) 轮")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.secondaryLabel)
                        .monospacedDigit()
                }
                .fixedSize()
                .tint(Theme.tint)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
        }
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { settings.refreshInterval },
            set: { newValue in
                settings.refreshInterval = newValue
                settings.persist()
            }
        )
    }

    private var rulesSection: some View {
        GroupedSection(
            "页面",
            footer: "概率是「到轮次之后有多大概率换一批」。调高会更热闹，也更费 token。"
        ) {
            ForEach(Array(RefreshPage.allCases.enumerated()), id: \.element) { index, page in
                ruleRow(page)

                if index < RefreshPage.allCases.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private func ruleRow(_ page: RefreshPage) -> some View {
        let rule = settings.rule(for: page)

        return VStack(spacing: 0) {
            HStack(spacing: PhoneMetrics.Space.s) {
                Image(systemName: page.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: PhoneMetrics.Radius.iconTile, style: .continuous)
                            .fill(Theme.IconTint.indigo)
                    )

                Text(page.title)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)

                Toggle("", isOn: enabledBinding(page))
                    .labelsHidden()
                    .tint(Theme.tint)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)

            if rule.enabled {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Slider(value: probabilityBinding(page), in: 0.02...0.6, step: 0.01)
                        .tint(Theme.tint)

                    Text("\(Int((rule.probability * 100).rounded()))%")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(Theme.secondaryLabel)
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.bottom, PhoneMetrics.Space.s)
            }
        }
    }

    private func enabledBinding(_ page: RefreshPage) -> Binding<Bool> {
        Binding(
            get: { settings.rule(for: page).enabled },
            set: { newValue in
                var rule = settings.rule(for: page)
                rule.enabled = newValue
                settings.updateRule(rule)
            }
        )
    }

    private func probabilityBinding(_ page: RefreshPage) -> Binding<Double> {
        Binding(
            get: { settings.rule(for: page).probability },
            set: { newValue in
                var rule = settings.rule(for: page)
                rule.probability = newValue
                settings.updateRule(rule)
            }
        )
    }

    private var billingNote: some View {
        GroupedSection("计费方式的影响") {
            VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
                Text("按次计费：判定要刷的那一轮，页面内容跟聊天回复在同一个请求里返回，不额外调用。多个页面可以同时刷。")
                Text("按量计费：同样按上面的概率判定，但一轮最多只放一个页面进来，把多出来的 token 压到最小。")
            }
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.s)
        }
    }
}
