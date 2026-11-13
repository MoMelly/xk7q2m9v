import SwiftUI

/// 应用商店。
///
/// 桌面上的图标可以删掉，删掉之后数据还在，但那个入口就没了——之前删错了
/// 只能重装软件。这一页把那批 App 重新列出来，装回去只是往桌面补一格。
///
/// 商店自己就在桌面第一屏，删不掉：它是唯一的恢复入口。
/// 底栏固定四个，同样不参与装卸。
struct AppStorePage: View {
    var onExit: () -> Void

    @State private var installed: Set<String> = []
    @State private var toast: String?

    var body: some View {
        AppScreen(title: "应用商店", onClose: onExit) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    intro

                    GroupedSection(
                        "可以装回来的",
                        footer: "卸载只是把桌面那一格拿走。聊天记录、角色、书和听歌记录都还在，装回来还是原来那个。"
                    ) {
                        ForEach(Array(AppCatalog.installable.enumerated()), id: \.element.id) { index, app in
                            if index > 0 { RowDivider() }
                            row(app)
                        }
                    }

                    GroupedSection(
                        "固定在桌面",
                        footer: "应用商店是唯一能把图标装回来的地方，所以它自己不给卸，也不会被拖进文件夹。"
                    ) {
                        ForEach(Array(AppCatalog.home.filter(\.isPinned).enumerated()), id: \.element.id) { index, app in
                            if index > 0 { RowDivider() }
                            pinnedRow(app)
                        }
                    }

                    GroupedSection(
                        "底栏",
                        footer: "底栏这四个删不掉，也不能拖到桌面上——位置固定，熟了就靠肌肉记忆点。"
                    ) {
                        ForEach(Array(AppCatalog.dock.enumerated()), id: \.element.id) { index, app in
                            if index > 0 { RowDivider() }
                            dockRow(app)
                        }
                    }

                    GroupedSection(footer: "把桌面恢复成刚装好的样子：清单里的 App 全部装回来，按默认顺序排。") {
                        Button {
                            HomeLayout.restoreStandard()
                            refresh()
                            flash("桌面已恢复")
                        } label: {
                            GroupedRow(
                                symbol: "arrow.counterclockwise",
                                symbolTint: Theme.IconTint.indigo,
                                title: "恢复默认桌面"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        // 页内提示用一层浮字，不走系统 alert：装一个 App 不该被打断。
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .glassSurface(cornerRadius: 22)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: refresh)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xxs) {
            Text("这里放的都是这部手机里能用的东西")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
            Text("装上去会在桌面最后一页多一个图标，不会顶掉你排好的位置。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    private func row(_ app: PhoneApp) -> some View {
        let on = installed.contains(app.id)
        return HStack(spacing: PhoneMetrics.Space.s) {
            AppIconTile(app: app, size: 46, showsLabel: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                Text(blurb(app))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            Button {
                toggle(app)
            } label: {
                Text(on ? "卸载" : "安装")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(on ? AppSurface.light.secondaryLabel : Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(
                        Capsule().fill(
                            on ? AppSurface.light.secondaryLabel.opacity(0.16) : Theme.tint
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
    }

    private func dockRow(_ app: PhoneApp) -> some View {
        fixedRow(app, label: "固定在底栏")
    }

    private func pinnedRow(_ app: PhoneApp) -> some View {
        fixedRow(app, label: "固定在桌面")
    }

    private func fixedRow(_ app: PhoneApp, label: String) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            AppIconTile(app: app, size: 46, showsLabel: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                Text(blurb(app))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            Text(label)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
    }

    private func blurb(_ app: PhoneApp) -> String {
        Self.blurbs[app.id] ?? ""
    }

    private static let blurbs: [String: String] = [
        "music": "放歌、看歌词，锁屏上也能控制",
        "calendar": "今天有什么，谁约了你",
        "notes": "随手记，也能写成一篇长文",
        "letters": "慢一点的那种话",
        "couple": "两个人的空间，火花和纪念日",
        "storygame": "分支剧情，选了就回不去",
        "reading": "导入书、翻页、划句子",
        "store": "卸掉的 App 从这里装回来",
        "dock.messages": "跟角色说话，都在这儿",
        "dock.feed": "动态、私信、帖子",
        "dock.phonepeek": "翻他的相册、备忘录、聊天",
        "dock.settings": "身份、模型、外观、数据"
    ]

    private func toggle(_ app: PhoneApp) {
        if installed.contains(app.id) {
            HomeLayout.remove(app.id)
            flash("「\(app.name)」已从桌面移除，数据还在")
        } else {
            HomeLayout.install(app.id)
            flash("「\(app.name)」已装到桌面")
        }
        refresh()
    }

    private func flash(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        }
    }

    private func refresh() {
        installed = Set(
            HomeLayout.load().pages.flatMap { $0.flatMap(\.appIDs) }
        )
    }
}
