import SwiftUI

/// 接口与计费。
struct EndpointPage: View {
    @Bindable var settings: SettingsStore

    private var billingBinding: Binding<BillingMode> {
        Binding(
            get: { settings.billingMode },
            set: { settings.setBillingMode($0) }
        )
    }

    var body: some View {
        AppPage(title: "接口与计费") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        "接口",
                        footer: "OpenAI 兼容地址，末尾不用写 /chat/completions。硅基流动、DeepSeek 官方、本地 Ollama 都能填。"
                    ) {
                        field("https://api.siliconflow.cn/v1", text: $settings.baseURL, isURL: true)
                        RowDivider()
                        field("模型名", text: $settings.model)
                        RowDivider()
                        SecureField("sk-...", text: $settings.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(Theme.label)
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    GroupedSection(
                        "计费方式",
                        footer: settings.billingMode.detail + "。按模型分别记住，换模型会自动带出上次选的值。"
                    ) {
                        Picker("计费", selection: billingBinding) {
                            ForEach(BillingMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onChange(of: settings.baseURL) { _, _ in settings.persist() }
        .onChange(of: settings.model) { _, _ in
            settings.syncBillingModeForModel()
            settings.persist()
        }
        .onChange(of: settings.apiKey) { _, _ in settings.persist() }
    }

    private func field(_ placeholder: String, text: Binding<String>, isURL: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(isURL ? .URL : .default)
            .font(.system(size: PhoneMetrics.FontSize.sub))
            .foregroundStyle(Theme.label)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
    }
}
