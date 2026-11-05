import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置页。
///
/// 不用 `Form`：外壳强制深色模式，`Form` 的 grouped 单元格会跟着系统变黑，
/// 叠在深色渐变上就是一层脏灰框。改成白底 + 白色玻璃卡片的自绘分组，
/// 颜色全部走绝对色值，不随配色方案翻转。
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(WorldStore.self) private var world

    @State private var shareItem: ShareItem?
    @State private var showRestore = false
    @State private var showVideoImporter = false
    @State private var alertText: String?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    endpointSection
                    keySection
                    billingSection
                    samplingSection
                    behaviorSection
                    privacySection
                    wallpaperSection
                    videoWallpaperSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.settingsBackground.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: settings.baseURL) { _, _ in settings.persist() }
            .onChange(of: settings.model) { _, _ in
                settings.syncBillingModeForModel()
                settings.persist()
            }
            .onChange(of: settings.apiKey) { _, _ in settings.persist() }
            .onChange(of: settings.temperature) { _, _ in settings.persist() }
            .onChange(of: settings.maxTokens) { _, _ in settings.persist() }
            .onChange(of: settings.notifyReplies) { _, newValue in
                settings.persist()
                if newValue {
                    Task { await ReplyNotifier.requestAuthorizationIfNeeded() }
                }
            }
            .onChange(of: settings.allowPhoneLookups) { _, _ in settings.persist() }
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
                allowedContentTypes: [.json, .folder],
                allowsMultipleSelection: false
            ) { result in
                handleRestore(result)
            }
            .fileImporter(
                isPresented: $showVideoImporter,
                allowedContentTypes: [.movie],
                allowsMultipleSelection: false
            ) { result in
                handleVideoImport(result)
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

    // MARK: - 分组

    private func group<Content: View>(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .whiteCard(cornerRadius: 14)

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.settingsBackground)
            .frame(height: 0.7)
    }

    private var endpointSection: some View {
        group("接口", footer: "OpenAI 兼容地址，末尾不用写 /chat/completions。硅基流动、DeepSeek 官方、本地 Ollama 都能填。") {
            TextField("https://api.siliconflow.cn/v1", text: $settings.baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 14))
                .rowPadding()
            rowDivider
            TextField("模型名", text: $settings.model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14))
                .rowPadding()
        }
    }

    private var keySection: some View {
        group("密钥", footer: "只存 Keychain，本机解锁后可读，不上云、不进备份、不经过任何服务器。") {
            SecureField("sk-...", text: $settings.apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14))
                .rowPadding()
        }
    }

    private var billingSection: some View {
        group("计费方式", footer: settings.billingMode.detail + "。按模型分别记住，换模型会自动带出上次选的值。") {
            Picker("这个模型的计费", selection: Binding(
                get: { settings.billingMode },
                set: { settings.setBillingMode($0) }
            )) {
                ForEach(BillingMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 14))
            .rowPadding()
        }
    }

    private var samplingSection: some View {
        group("生成参数", footer: "温度高一点角色更有脾气，太低会像客服。上限只是保险，正常回复用不到。") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.1f", settings.temperature))
                        .font(.system(size: 13).monospaced())
                        .foregroundStyle(Theme.secondaryInk)
                }
                Slider(value: $settings.temperature, in: 0...1.5, step: 0.1)
            }
            .font(.system(size: 14))
            .rowPadding()
            rowDivider
            Stepper("单次上限 \(settings.maxTokens) tokens",
                    value: $settings.maxTokens, in: 200...4000, step: 100)
                .font(.system(size: 14))
                .rowPadding()
        }
    }

    private var behaviorSection: some View {
        group("行为", footer: "只在你切出去之后提醒——不是角色主动找你。用的是本地通知，不需要推送证书，也不花钱。") {
            Toggle("回复到了提醒我", isOn: $settings.notifyReplies)
                .font(.system(size: 14))
                .rowPadding()
        }
    }

    private var privacySection: some View {
        group("隐私", footer: "开了之后，角色能看到电量、机型、时区，以及你在这台小手机里各个页面的停留时长。真实健康数据和系统屏幕时间不在此列，免费签名拿不到这两项权限。默认关闭。") {
            Toggle("允许角色查手机", isOn: $settings.allowPhoneLookups)
                .font(.system(size: 14))
                .rowPadding()
        }
    }

    private var wallpaperSection: some View {
        group("壁纸", footer: "选完立刻生效，退回桌面就能看到。") {
            ForEach(Array(WallpaperTheme.allCases.enumerated()), id: \.offset) { index, theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        settings.setWallpaper(theme)
                    }
                } label: {
                    HStack(spacing: 12) {
                        WallpaperSwatch(theme: theme)
                        Text(theme.displayName)
                            .font(.system(size: 14))
                        Spacer(minLength: 0)
                        if settings.wallpaperRaw == theme.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.retroGreen)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowPadding()
                if index < WallpaperTheme.allCases.count - 1 {
                    rowDivider
                }
            }
        }
    }

    private var videoWallpaperSection: some View {
        group("视频壁纸", footer: "导入本地 mp4 / mov，锁屏和桌面共用一层，静音循环。视频会随备份导出；歌单随软件发布，不进备份。") {
            Button {
                showVideoImporter = true
            } label: {
                HStack {
                    Text(VideoWallpaperStore.exists ? "重新导入视频" : "导入视频")
                        .font(.system(size: 14))
                    Spacer(minLength: 0)
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.retroGreen)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .rowPadding()

            if VideoWallpaperStore.exists {
                rowDivider
                Toggle("启用视频壁纸", isOn: $settings.videoWallpaperEnabled)
                    .font(.system(size: 14))
                    .rowPadding()
                    .onChange(of: settings.videoWallpaperEnabled) { _, _ in settings.persist() }
            }
        }
    }

    private var dataSection: some View {
        group("数据", footer: "导出的是一个文件夹：data.json 加上视频壁纸。恢复时选这个文件夹或里面的 json 都行。歌单随软件发布，重装不用重新导。") {
            Button {
                exportAll()
            } label: {
                Text("导出全部数据")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .rowPadding()
            rowDivider
            Button {
                showRestore = true
            } label: {
                Text("从备份恢复")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .rowPadding()
        }
    }

    private var aboutSection: some View {
        group("关于", footer: "聊天内容只写在本机数据库，除了发给你填的那个接口地址，不会离开这台设备。") {
            HStack {
                Text("版本")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(Theme.secondaryInk)
            }
            .font(.system(size: 14))
            .rowPadding()
            rowDivider
            HStack {
                Text("对话存储")
                Spacer()
                Text("仅本机")
                    .foregroundStyle(Theme.secondaryInk)
            }
            .font(.system(size: 14))
            .rowPadding()
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
                world.reload()
                alertText = summary
            } catch {
                alertText = "恢复失败：\(error.localizedDescription)"
            }
        }
    }

    private func handleVideoImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertText = "选文件失败：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try VideoWallpaperStore.importFrom(url)
                settings.videoWallpaperEnabled = true
                settings.persist()
                alertText = "视频壁纸已导入，退回锁屏就能看到。"
            } catch {
                alertText = "导入失败：\(error.localizedDescription)"
            }
        }
    }
}

