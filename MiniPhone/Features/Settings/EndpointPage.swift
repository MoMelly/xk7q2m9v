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

                    keyRotationSection
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

    // MARK: - Key 轮换

    @State private var draftKey = ""

    private var keyRotationSection: some View {
        GroupedSection(
            "备用 Key",
            footer: """
            主 Key 返回 401 / 402 / 403 / 429 时，按顺序换下一把重试，试通了就把它提到主位。
            500 和超时不会换——那是服务端自己的事，换 Key 只是把等待时间翻倍。
            备用 Key 也只存在钥匙串里。
            """
        ) {
            Toggle(isOn: Binding(
                get: { settings.keyRotation },
                set: { settings.setKeyRotation($0) }
            )) {
                Text("主 Key 失败时自动换备用")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
            }
            .tint(Theme.tint)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)

            ForEach(settings.extraKeys, id: \.self) { key in
                RowDivider()
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.IconTint.yellow)

                    Text(masked(key))
                        .font(.system(size: PhoneMetrics.FontSize.sub, design: .monospaced))
                        .foregroundStyle(Theme.label)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button {
                        settings.removeExtraKey(key)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.IconTint.pink.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }

            RowDivider()

            HStack(spacing: PhoneMetrics.Space.xs) {
                SecureField("再填一把 sk-...", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)

                Button("加入") {
                    settings.addExtraKey(draftKey)
                    draftKey = ""
                }
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(
                    draftKey.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Theme.secondaryLabel
                        : Theme.brand
                )
                .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    /// 只露尾巴四位。这是自己的钥匙串，不是要防谁——
    /// 但整把显示在屏幕上，截图和录屏就会把它带出去。
    private func masked(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 8 else { return "••••" }
        return "••••" + String(trimmed.suffix(4))
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
