import SwiftUI

/// 外壳总容器。
///
/// 三个状态：锁屏 → 桌面 → 打开某个 App。用状态机而不是 NavigationStack，
/// 因为真机是没有导航栏的，页面之间的关系是「盖上去」而不是「推过去」。
struct PhoneShellView: View {
    @Bindable var settings: SettingsStore
    @Environment(WorldStore.self) private var world

    @State private var isLocked: Bool = PhoneShellView.previewLocked
    @State private var openedApp: PhoneApp? = PhoneShellView.previewApp
    @State private var openedAt: Date?
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?

    // MARK: - 截图用的启动状态

    /// 启动参数 `-previewState lock|home|chat|moments|settings|calendar|music|health`
    /// 让外壳直接落到指定状态。截图流水线靠它跳过手势。
    private static var previewState: String {
        UserDefaults.standard.string(forKey: "previewState") ?? "lock"
    }

    private static var previewLocked: Bool {
        previewState == "lock"
    }

    private static var previewApp: PhoneApp? {
        let destination: PhoneApp.Destination?
        switch previewState {
        case "chat": destination = .chat
        case "moments": destination = .moments
        case "settings": destination = .settings
        case "calendar": destination = .scene(.calendar)
        case "notes": destination = .scene(.notes)
        case "photos": destination = .moments
        case "calls": destination = .scene(.calls)
        case "music": destination = .scene(.music)
        case "health": destination = .scene(.health)
        default: destination = nil
        }
        guard let destination else { return nil }
        return AppCatalog.home.first { $0.destination == destination }
    }

    var body: some View {
        ZStack {
            if isLocked {
                LockScreenView(
                    wallpaper: settings.wallpaperTheme,
                    onUnlock: unlock,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
            } else {
                HomeScreenView(
                    wallpaper: settings.wallpaperTheme,
                    onOpen: open,
                    videoWallpaperEnabled: settings.videoWallpaperEnabled
                )
                .transition(.opacity)
            }

            if let app = openedApp {
                appLayer(app)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: PhoneMetrics.appLaunchStartScale).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
                    .zIndex(2)
            }

            if let toastText {
                toast(toastText)
                    .zIndex(3)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isLocked)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: openedApp)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { @MainActor in
            world.ensureToday(wakeHour: 7, sleepHour: 23)
            world.seedSceneContentIfNeeded()
        }
    }

    // MARK: - App 层

    @ViewBuilder
    private func appLayer(_ app: PhoneApp) -> some View {
        switch app.destination {
        case .chat:
            ConversationListView(settings: settings, onExit: closeApp)
        case .moments:
            MomentsView(settings: settings, onExit: closeApp)
        case .settings:
            SettingsView(settings: settings, onExit: closeApp)
        case .scene(let kind):
            ScenePage(kind: kind, settings: settings, world: world, onExit: closeApp)
        case .placeholder:
            // 占位图标不会走进来，open(_:) 里已经拦掉了。
            EmptyView()
        }
    }

    // MARK: - Toast

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .glassSurface(cornerRadius: 22)

            Spacer(minLength: 0).frame(height: 130)
        }
        .transition(.opacity.combined(with: .offset(y: 14)))
    }

    @MainActor
    private func showToast(_ text: String) {
        toastTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            toastText = text
        }

        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toastText = nil
            }
        }
    }

    // MARK: - 状态切换

    private func unlock() {
        isLocked = false
    }

    private func open(_ app: PhoneApp) {
        switch app.destination {
        case .chat, .moments, .settings, .scene:
            openedApp = app
            openedAt = Date()
        case .placeholder:
            showToast("「\(app.name)」还没做")
        }
    }

    private func closeApp() {
        if let app = openedApp, let start = openedAt {
            world.noteUsage(appName: app.name, seconds: Date().timeIntervalSince(start))
        }
        openedApp = nil
        openedAt = nil
    }
}
