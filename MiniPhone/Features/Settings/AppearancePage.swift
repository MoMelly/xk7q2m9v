import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 外观与壁纸。
///
/// 桌面和锁屏分开设：真机上这两块本来就是两张图，
/// 但只改一处的人更多，所以默认锁屏跟着桌面走，需要时才拆开。
struct AppearancePage: View {
    @Bindable var settings: SettingsStore

    @State private var scope: WallpaperScope = .home
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoError: String?
    @State private var showVideoImporter = false
    @State private var alertText: String?

    private var isLock: Bool { scope == .lock }

    private var current: WallpaperSelection {
        isLock ? settings.lockSelection : settings.homeSelection
    }

    var body: some View {
        AppPage(title: "外观与壁纸") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    scopeSection
                    wallpaperSection
                    videoSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
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

    // MARK: - 作用范围

    private var scopeSection: some View {
        GroupedSection(footer: "锁屏和桌面可以各用一张。想改锁屏就先切到「锁屏」。") {
            Picker("", selection: $scope) {
                ForEach(WallpaperScope.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.xs)

            if isLock {
                RowDivider()

                Toggle(isOn: Binding(
                    get: { settings.lockSeparate },
                    set: { value in
                        settings.lockSeparate = value
                        settings.persist()
                    }
                )) {
                    Text("锁屏单独设置")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                }
                .tint(Theme.tint)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    // MARK: - 壁纸

    private var wallpaperSection: some View {
        GroupedSection("壁纸", footer: wallpaperFooter) {
            if isLock && !settings.lockSeparate {
                nothingToEditRow
            } else {
                themeRows
                photoRows
            }
        }
    }

    /// 锁屏没拆开时不做选择——让人选了却不生效比不让选更糟。
    private var nothingToEditRow: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xxs) {
            Text("现在锁屏跟桌面是同一张")
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(Theme.label)
            Text("打开上面的「锁屏单独设置」才能换锁屏。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PhoneMetrics.Space.m)
    }

    private var themeRows: some View {
        ForEach(Array(WallpaperTheme.allCases.enumerated()), id: \.offset) { index, theme in
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    select(theme)
                }
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    WallpaperSwatch(theme: theme)

                    Text(theme.displayName)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)

                    if !current.usesPhoto, current.theme == theme {
                        checkmark
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

    private var photoRows: some View {
        VStack(spacing: 0) {
            RowDivider()

            PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.tint)
                        .frame(width: 40, height: 40)

                    Text(current.usesPhoto ? "换一张自己的图" : "用相册里的图")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let message = photoError {
                Text(message)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.bottom, PhoneMetrics.Space.xs)
            }

            if current.usesPhoto {
                RowDivider()

                Button {
                    clearPhoto()
                } label: {
                    HStack(spacing: PhoneMetrics.Space.s) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.secondaryLabel)
                            .frame(width: 40, height: 40)

                        Text("不用自己的图")
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(Theme.label)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.detailed)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.tint)
    }

    private var wallpaperFooter: String {
        if isLock && !settings.lockSeparate {
            return "锁屏可以跟桌面不一样，打开上面的开关就能单独换。"
        }
        return "选完立刻生效，退回桌面或锁屏就能看到。照片只存在本机。"
    }

    // MARK: - 视频

    private var videoSection: some View {
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

    // MARK: - 动作

    private func select(_ theme: WallpaperTheme) {
        // 在锁屏那一栏选了东西，就等于表态「锁屏要单独设」，
        // 不然点完什么也没变，会以为坏了。
        if isLock { settings.lockSeparate = true }
        settings.setWallpaper(theme, lock: isLock)
    }

    private func clearPhoto() {
        let old = isLock ? settings.lockWallpaperPhoto : settings.homeWallpaperPhoto
        settings.setWallpaperPhoto("", lock: isLock)
        WallpaperPhoto.delete(fileName: old)
        photoError = nil
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        photoError = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            photoError = "这张图读不出来，换一张试试。"
            return
        }

        do {
            let name = try WallpaperPhoto.save(image: image)
            let old = isLock ? settings.lockWallpaperPhoto : settings.homeWallpaperPhoto
            if isLock { settings.lockSeparate = true }
            settings.setWallpaperPhoto(name, lock: isLock)
            WallpaperPhoto.delete(fileName: old)
        } catch {
            photoError = (error as? LocalizedError)?.errorDescription ?? "存不下这张图。"
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

/// 当前在改哪一张。
enum WallpaperScope: String, CaseIterable, Identifiable {
    case home
    case lock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "桌面"
        case .lock: return "锁屏"
        }
    }
}
