import SwiftUI

/// 主题：主题色、图标样式、日间夜间、壁纸入口。
///
/// 单独一页而不是塞进「外观与壁纸」：那页管的是壁纸本身，
/// 这一页管的是「整套界面长什么样」，两件事放一起会互相盖住。
struct ThemePage: View {
    @Bindable var settings: SettingsStore

    private var theme: ThemeStore { .shared }

    private let accentColumns = Array(
        repeating: GridItem(.flexible(), spacing: 14),
        count: 7
    )

    private var sampleApps: [PhoneApp] {
        Array(AppCatalog.home.prefix(2))
    }

    var body: some View {
        AppPage(title: "主题") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    preview
                    accentSection
                    iconSection
                    appearanceSection
                    glassSection
                    wallpaperLink
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    // MARK: - 预览

    private var preview: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ForEach(AppCatalog.home.prefix(5)) { app in
                    AppIconTile(app: app, size: 46, showsLabel: false)
                }
            }

            Text("桌面上长这样")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    // MARK: - 主题色

    private var accentSection: some View {
        GroupedSection(
            "主题色",
            footer: "换一个色，西瓜皮、市集按钮、选中态、图标图形一起跟着变。"
        ) {
            LazyVGrid(columns: accentColumns, spacing: 14) {
                ForEach(AccentTheme.allCases.filter { $0 != .custom }) { item in
                    accentSwatch(item)
                }
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { theme.accent },
                        set: { theme.select(custom: $0) }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 34, height: 34)
                .overlay {
                    Circle()
                        .strokeBorder(
                            theme.accentTheme == .custom ? Theme.brand : Color.clear,
                            lineWidth: 2
                        )
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.m)

            RowDivider()

            HStack(spacing: PhoneMetrics.Space.s) {
                Text("当前")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)

                Spacer(minLength: 0)

                Text(theme.accentTheme == .custom ? "自定义 \(theme.customAccentHex)" : theme.accentTheme.displayName)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    private func accentSwatch(_ item: AccentTheme) -> some View {
        Button {
            theme.select(item)
        } label: {
            ZStack {
                Circle()
                    .fill(item.color ?? Theme.brand)
                    .frame(width: 34, height: 34)

                Circle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.8)
                    .frame(width: 34, height: 34)
                    .opacity(item.color == nil ? 0 : 1)

                if theme.accentTheme == item {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 图标样式

    private var iconSection: some View {
        GroupedSection(
            "图标样式",
            footer: "彩色玻璃是每个 App 自己的配色；矢量版底色只有三种，图形统一用主题色。"
        ) {
            ForEach(Array(IconStyle.allCases.enumerated()), id: \.element.id) { index, style in
                Button {
                    theme.select(style)
                } label: {
                    HStack(spacing: PhoneMetrics.Space.s) {
                        HStack(spacing: 6) {
                            ForEach(sampleApps) { app in
                                AppIconTile(
                                    app: app,
                                    size: 28,
                                    showsLabel: false,
                                    styleOverride: style
                                )
                            }
                        }
                        .frame(width: 68, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)

                            Text(style.caption)
                                .font(.system(size: PhoneMetrics.FontSize.caption))
                                .foregroundStyle(Theme.secondaryInk)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        if theme.iconStyle == style {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.tint)
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < IconStyle.allCases.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    // MARK: - 日间 / 夜间

    private var appearanceSection: some View {
        GroupedSection(
            "日间与夜间",
            footer: "夜间给所有页面压一层黑、文字转白，聊天页和动态页本来就是深的，不会再翻一次。"
        ) {
            HStack(spacing: PhoneMetrics.Space.s) {
                ForEach(AppearanceMode.allCases) { mode in
                    modeButton(mode)
                }
            }
            .padding(PhoneMetrics.Space.m)
        }
    }

    private func modeButton(_ mode: AppearanceMode) -> some View {
        let selected = theme.appearance == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                theme.select(mode)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(mode == .day
                              ? Theme.IconSurface.dayPreview
                              : Theme.IconSurface.nightPreview)
                        .frame(height: 56)

                    Image(systemName: mode == .day ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(mode == .day
                                         ? Theme.IconSurface.sunGlyph
                                         : Theme.IconSurface.moonGlyph)
                }

                Text(mode.displayName)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.brand : Theme.label)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .strokeBorder(selected ? Theme.brand : Theme.separator.opacity(0.6), lineWidth: selected ? 1.6 : 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 磨砂厚薄

    /// 三档，每档给一块小样：同一张底垫上不同厚度的白，选之前就能看出来差在哪。
    private var glassSection: some View {
        GroupedSection(
            "磨砂厚薄",
            footer: "Dock、小组件、歌词页这些半透明的面都跟着这一档走。壁纸很花的时候调厚一点，字才压得住。"
        ) {
            HStack(spacing: PhoneMetrics.Space.s) {
                ForEach(GlassDensity.allCases) { density in
                    densityButton(density)
                }
            }
            .padding(PhoneMetrics.Space.m)
        }
    }

    private func densityButton(_ density: GlassDensity) -> some View {
        let selected = theme.glassDensity == density

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.select(density)
            }
        } label: {
            VStack(spacing: 7) {
                // 小样本身就是一块磨砂：底下放两个色块，白垫越厚盖得越多。
                ZStack {
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.IconTint.rose)
                        Rectangle().fill(Theme.IconTint.teal)
                    }
                    Color.white.opacity(min(0.9, 0.20 * density.factor * 1.6))
                }
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))

                Text(density.displayName)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.brand : Theme.label)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .strokeBorder(selected ? Theme.brand : Theme.separator.opacity(0.6),
                                  lineWidth: selected ? 1.6 : 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("磨砂\(density.displayName)")
    }

    // MARK: - 壁纸入口

    private var wallpaperLink: some View {
        GroupedSection("壁纸", footer: "内置四套，也可以用相册里的照片，桌面和锁屏可以分开设。") {
            NavigationLink {
                AppearancePage(settings: settings)
            } label: {
                GroupedRow(
                    symbol: "photo.on.rectangle",
                    symbolTint: Theme.IconTint.purple,
                    title: "换壁纸"
                )
            }
            .buttonStyle(.plain)
        }
    }
}
