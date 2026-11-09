import SwiftUI

/// 控制中心的开关与滑杆。
///
/// 全部只存在本机：这个壳子不连真实网络，飞行模式、蜂窝、蓝牙都没有可操作的对象。
/// 那为什么还要做——因为一台手机从右上角拉下来什么都没有，比有一个假开关更假。
/// 开关本身只影响界面：勿扰关掉的是通知横幅，亮度调的是这一层蒙黑，音量落到播放器上。
@Observable
@MainActor
final class ControlCenterStore {
    static let shared = ControlCenterStore()

    private enum Key {
        static let wifi = "cc.wifi"
        static let cellular = "cc.cellular"
        static let bluetooth = "cc.bluetooth"
        static let airplane = "cc.airplane"
        static let silent = "cc.silent"
        static let brightness = "cc.brightness"
        static let volume = "cc.volume"
    }

    var wifi = true
    var cellular = true
    var bluetooth = false
    var airplane = false
    /// 勿扰。开着的时候来消息不弹横幅。
    var silent = false
    /// 0.25~1。低于这个数屏幕就黑得看不清东西了。
    var brightness = 0.92
    var volume: Double = 0.7 {
        didSet { PlayerService.shared.volume = volume }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.wifi) != nil {
            wifi = defaults.bool(forKey: Key.wifi)
            cellular = defaults.bool(forKey: Key.cellular)
            bluetooth = defaults.bool(forKey: Key.bluetooth)
            airplane = defaults.bool(forKey: Key.airplane)
            silent = defaults.bool(forKey: Key.silent)
            brightness = defaults.double(forKey: Key.brightness)
            volume = defaults.double(forKey: Key.volume)
        }
    }

    func toggle(_ item: Item) {
        switch item {
        case .airplane:
            airplane.toggle()
            // 飞行模式真的把另外两个关掉，否则开关之间互相矛盾。
            if airplane {
                wifi = false
                cellular = false
            }
        case .cellular: cellular.toggle()
        case .wifi: wifi.toggle()
        case .bluetooth: bluetooth.toggle()
        case .silent: silent.toggle()
        }
        save()
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(wifi, forKey: Key.wifi)
        defaults.set(cellular, forKey: Key.cellular)
        defaults.set(bluetooth, forKey: Key.bluetooth)
        defaults.set(airplane, forKey: Key.airplane)
        defaults.set(silent, forKey: Key.silent)
        defaults.set(brightness, forKey: Key.brightness)
        defaults.set(volume, forKey: Key.volume)
    }

    enum Item: String, CaseIterable, Identifiable {
        case airplane
        case cellular
        case wifi
        case bluetooth
        case silent

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .airplane: return "airplane"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wifi: return "wifi"
            case .bluetooth: return "bluetooth"
            case .silent: return "moon.fill"
            }
        }

        var title: String {
            switch self {
            case .airplane: return "飞行模式"
            case .cellular: return "蜂窝网络"
            case .wifi: return "无线局域网"
            case .bluetooth: return "蓝牙"
            case .silent: return "勿扰"
            }
        }
    }
}

/// 蓝牙符号。系统符号库里不一定有这个，缺了就是一片空白，所以手画。
///
/// 一笔连成的折线：从右上角斜下来，中间竖到底再折回去，收尾在右下角。
struct BluetoothGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.28, 0.30))
        path.addLine(to: point(0.72, 0.70))
        path.addLine(to: point(0.50, 1.00))
        path.addLine(to: point(0.50, 0.00))
        path.addLine(to: point(0.72, 0.30))
        path.addLine(to: point(0.28, 0.70))
        return path
    }
}

/// 从右上角拉下来的那一整块。
///
/// 形状照 iOS：一块大圆角磨砂，左上四个圆钮、右上音乐、下面两条横滑杆、底部一排快捷。
/// 不放「深色模式」这类开关——那在设置里，两处都能改只会让人不知道哪边算数。
struct ControlCenterPanel: View {
    let world: WorldStore
    @Bindable var settings: SettingsStore
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    private var store: ControlCenterStore { .shared }
    private let player = PlayerService.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                radios
                musicCard
            }

            slider(symbol: "sun.max.fill", value: brightnessBinding)
            slider(symbol: "speaker.wave.2.fill", value: volumeBinding)

            shortcuts
        }
        .padding(14)
        .frostedSheet(cornerRadius: 40)
        .padding(.horizontal, 10)
    }

    // MARK: - 连接

    private var radios: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                radio(.airplane)
                radio(.cellular)
            }
            HStack(spacing: 10) {
                radio(.wifi)
                radio(.bluetooth)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frostedBar(cornerRadius: 26, shadow: .none)
    }

    private func radio(_ item: ControlCenterStore.Item) -> some View {
        let on = isOn(item)
        return Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.16)) {
                store.toggle(item)
            }
        } label: {
            glyph(item, on: on)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(on ? Theme.link : Color.white.opacity(0.26))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(on ? "开" : "关")
    }

    /// 蓝牙那个符号在某些系统版本上根本不存在，`Image(systemName:)` 找不到时
    /// 什么也不画——截图里就是一个空圈。所以这里自己画，不赌符号库里有。
    @ViewBuilder
    private func glyph(_ item: ControlCenterStore.Item, on: Bool) -> some View {
        let ink = on ? Color.white : Theme.label.opacity(0.62)

        if item == .bluetooth {
            BluetoothGlyph()
                .stroke(ink, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 20)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ink)
        }
    }

    private func isOn(_ item: ControlCenterStore.Item) -> Bool {
        switch item {
        case .airplane: return store.airplane
        case .cellular: return store.cellular
        case .wifi: return store.wifi
        case .bluetooth: return store.bluetooth
        case .silent: return store.silent
        }
    }

    // MARK: - 音乐

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.IconTint.purple.opacity(0.8))
                        .frame(width: 30, height: 30)
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(player.track?.title ?? "没在放")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.label)
                        .lineLimit(1)
                    Text(player.track?.artist ?? "去音乐里挑一首")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                control("backward.fill") { player.previous() }
                control(player.isPlaying ? "pause.fill" : "play.fill") { player.toggle() }
                control("forward.fill") { player.next() }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frostedBar(cornerRadius: 26, shadow: .none)
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.label)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .disabled(player.track == nil)
        .opacity(player.track == nil ? 0.4 : 1)
    }

    // MARK: - 滑杆

    private var brightnessBinding: Binding<Double> {
        Binding(get: { store.brightness }, set: { store.brightness = $0 })
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { store.volume }, set: { store.volume = $0 })
    }

    private func slider(symbol: String, value: Binding<Double>) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let ratio = min(max(value.wrappedValue, 0), 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: max(36, width * ratio))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .padding(.leading, 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        value.wrappedValue = min(max(drag.location.x / width, 0), 1)
                    }
                    .onEnded { _ in store.save() }
            )
        }
        .frame(height: 40)
        .clipShape(Capsule())
    }

    // MARK: - 底部快捷

    private var shortcuts: some View {
        HStack(spacing: 10) {
            shortcut(
                symbol: store.silent ? "moon.fill" : "moon",
                title: "勿扰",
                on: store.silent
            ) {
                store.toggle(.silent)
            }

            shortcut(
                symbol: settings.discreetMode ? "eye.slash.fill" : "eye.slash",
                title: "隐藏",
                on: settings.discreetMode
            ) {
                settings.setDiscreetMode(!settings.discreetMode)
            }

            shortcut(symbol: "gear", title: "设置", on: false) {
                onOpenSettings()
            }

            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("收起控制中心")
        }
    }

    private func shortcut(
        symbol: String,
        title: String,
        on: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.16)) { action() }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Theme.label)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(on ? Theme.link : Color.white.opacity(0.16)))
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
