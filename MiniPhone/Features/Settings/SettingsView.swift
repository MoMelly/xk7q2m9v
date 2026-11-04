import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置页。
///
/// 两个入口共用：从桌面「设置」图标进来（`onExit` 退回桌面，此时是 nil 的话用 dismiss）。
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var shareItem: ShareItem?
    @State private var showRestore = false
    @State private var alertText: String?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            Form {
                endpointSection
                keySection
                samplingSection
                behaviorSection
                wallpaperSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: settings.baseURL) { _, _ in settings.persist() }
            .onChange(of: settings.model) { _, _ in settings.persist() }
            .onChange(of: settings.apiKey) { _, _ in settings.persist() }
            .onChange(of: settings.temperature) { _, _ in settings.persist() }
            .onChange(of: settings.maxTokens) { _, _ in settings.persist() }
            .onChange(of: settings.notifyReplies) { _, newValue in
                settings.persist()
                if newValue {
                    Task { await ReplyNotifier.requestAuthorizationIfNeeded() }
                }
            }
            .onDisappear { settings.persist() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let onExit { onExit() } else { dismiss() }
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
            }
            .fileImporter(
                isPresented: $showRestore,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleRestore(result)
            }
            .alert("提示", isPresented: Binding(
                get: { alertText != nil },
                set: { if !$0 { alertText = nil } }
            )) {
                Button("好") { alertText = nil }
            } message: {
                Text(alertText ?? "")
            }
        }
    }

    // MARK: - 分区

    private var endpointSection: some View {
        Section {
            TextField("https://api.siliconflow.cn/v1", text: $settings.baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField("模型名", text: $settings.model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("接口")
        } footer: {
            Text("OpenAI 兼容地址，末尾不用写 /chat/completions。硅基流动、DeepSeek 官方、本地 Ollama 都能填。")
        }
    }

    private var keySection: some View {
        Section {
            SecureField("sk-...", text: $settings.apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("密钥")
        } footer: {
            Text("只存 Keychain，本机解锁后可读，不上云、不进备份、不经过任何服务器。")
        }
    }

    private var samplingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.1f", settings.temperature))
                        .font(.system(size: 13).monospaced())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.temperature, in: 0...1.5, step: 0.1)
            }

            Stepper("单次上限 \(settings.maxTokens) tokens",
                    value: $settings.maxTokens, in: 200...4000, step: 100)
        } header: {
            Text("生成参数")
        } footer: {
            Text("温度高一点角色更有脾气，太低会像客服。上限只是保险，正常回复用不到。")
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("回复到了提醒我", isOn: $settings.notifyReplies)
        } header: {
            Text("行为")
        } footer: {
            Text("只在你切出去之后提醒——不是角色主动找你。用的是本地通知，不需要推送证书，也不花钱。")
        }
    }

    private var wallpaperSection: some View {
        Section {
            ForEach(WallpaperTheme.allCases) { theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        settings.setWallpaper(theme)
                    }
                } label: {
                    HStack(spacing: 12) {
                        WallpaperSwatch(theme: theme)

                        Text(theme.displayName)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        if settings.wallpaperRaw == theme.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.retroGreen)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text("壁纸")
        } footer: {
            Text("选完立刻生效，退回桌面就能看到。")
        }
    }

    private var dataSection: some View {
        Section {
            Button("导出全部数据") { exportAll() }
            Button("从备份恢复") { showRestore = true }
        } header: {
            Text("数据")
        } footer: {
            Text("免费签名重装一次等于全新安装，App 里的东西会清空。定期导出一份，重装后再恢复。导出文件是明文 JSON。")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("对话存储")
                Spacer()
                Text("仅本机")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("关于")
        } footer: {
            Text("聊天内容只写在本机数据库，除了发给你填的那个接口地址，不会离开这台设备。")
        }
    }

    // MARK: - 动作

    private func exportAll() {
        do {
            let url = try DataBackup.export(context: context)
            shareItem = ShareItem(url: url)
        } catch {
            alertText = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertText = "选文件失败：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let summary = try DataBackup.restore(from: url, context: context)
                alertText = summary
            } catch {
                alertText = "恢复失败：\(error.localizedDescription)"
            }
        }
    }
}

/// 壁纸预览小方块。只画基底渐变，不画光斑——尺寸太小，光斑糊成一团反而看不清差别。
private struct WallpaperSwatch: View {
    let theme: WallpaperTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(
                    colors: theme.baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 46, height: 46)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
    }
}
