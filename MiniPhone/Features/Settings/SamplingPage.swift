import SwiftUI

/// 生成参数。
struct SamplingPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        AppPage(title: "生成参数") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        "采样",
                        footer: "温度高一点角色更有脾气，太低会像客服。上限只是保险，正常回复用不到。"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("温度")
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(Theme.label)
                                Spacer(minLength: 0)
                                Text(String(format: "%.1f", settings.temperature))
                                    .font(.system(size: PhoneMetrics.FontSize.sub).monospacedDigit())
                                    .foregroundStyle(Theme.secondaryLabel)
                            }

                            Slider(value: $settings.temperature, in: 0...1.5, step: 0.1)
                                .tint(Theme.tint)
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, 10)

                        RowDivider()

                        Stepper(value: $settings.maxTokens, in: 200...4000, step: 100) {
                            HStack {
                                Text("单次上限")
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(Theme.label)
                                Spacer(minLength: 0)
                                Text("\(settings.maxTokens) tokens")
                                    .font(.system(size: PhoneMetrics.FontSize.sub))
                                    .foregroundStyle(Theme.secondaryLabel)
                            }
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onChange(of: settings.temperature) { _, _ in settings.persist() }
        .onChange(of: settings.maxTokens) { _, _ in settings.persist() }
    }
}
