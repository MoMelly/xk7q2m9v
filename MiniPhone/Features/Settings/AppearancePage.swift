import SwiftUI
import UniformTypeIdentifiers

/// 外观与壁纸。
struct AppearancePage: View {
    @Bindable var settings: SettingsStore

    @State private var showVideoImporter = false
    @State private var alertText: String?

    var body: some View {
        AppPage(title: "外观与壁纸") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection("壁纸", footer: "选完立刻生效，退回桌面就能看到。") {
                        ForEach(Array(WallpaperTheme.allCases.enumerated()), id: \.offset) { index, theme in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    settings.setWallpaper(theme)
                                }
                            } label: {
                                HStack(spacing: PhoneMetrics.Space.s) {
                                    WallpaperSwatch(theme: theme)

                                    Text(theme.displayName)
                                        .font(.system(size: PhoneMetrics.FontSize.body))
                                        .foregroundStyle(Theme.label)

                                    Spacer(minLength: 0)

                                    if settings.wallpaperRaw == theme.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.tint)
                                    }
                                }
                                .padding(.horizontal, PhoneMetrics.Space.m)
                                .frame(minHeight: PhoneMetrics.Row.detailed)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < WallpaperTheme.allCases.count - 1 {
                                RowDivider()
                            }
                        }
                    }

                    GroupedSection(
                        "视频壁纸",
                        footer: "导入本地 mp4 / mov，锁屏和桌面共用一层，静音循环。视频随备份导出。"
                    ) {
                        Button {
                            showVideoImporter = true
                        } label: {
                            GroupedRow(
                                symbol: "film",
                                symbolTint: Theme.IconTint.indigo,
                                title: VideoWallpaperStore.exists ? "重新导入视频" : "导入视频"
                            )
                        }
                        .buttonStyle(.plain)

                        if VideoWallpaperStore.exists {
                            RowDivider()

                            Toggle(isOn: $settings.videoWallpaperEnabled) {
                                Text("启用视频壁纸")
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(Theme.label)
                            }
                            .tint(Theme.tint)
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: PhoneMetrics.Row.single)
                            .onChange(of: settings.videoWallpaperEnabled) { _, _ in settings.persist() }
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
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
