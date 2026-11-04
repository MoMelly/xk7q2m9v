import SwiftUI

/// 设置页。
///
/// 两个入口共用这一个视图：从聊天页右上角进来（sheet，靠「完成」关闭），
/// 从桌面「设置」图标进来（全屏覆盖，靠「完成」退回桌面）。
/// 用可选的 `onExit` 区分，不写两套界面。
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("OpenAI 兼容地址，末尾不用写 /chat/completions。")
                }

                Section {
                    SecureField("sk-...", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("密钥")
                } footer: {
                    Text("只存 Keychain，本机解锁后可读，不上云、不进备份。")
                }

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
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: settings.baseURL) { _, _ in settings.persist() }
            .onChange(of: settings.model) { _, _ in settings.persist() }
            .onChange(of: settings.apiKey) { _, _ in settings.persist() }
            .onDisappear { settings.persist() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let onExit {
                            onExit()
                        } else {
                            dismiss()
                        }
                    }
                }
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
