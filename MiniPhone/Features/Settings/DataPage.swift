import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 数据与备份。
struct DataPage: View {
    @Environment(\.modelContext) private var context
    @Environment(WorldStore.self) private var world

    @State private var shareItem: ShareItem?
    @State private var showRestore = false
    /// 选完文件先停在这里，等用户点确认。恢复是整份覆盖，
    /// 点错一次就是全部重来，中间必须有一道门。
    @State private var pendingRestore: URL?
    @State private var alertText: String?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        AppPage(title: "数据与备份") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        footer: "导出的是一个文件夹：data.json、world-state.json、视频壁纸、头像照片，还有文游存档、自建表情（含名字和分组）、导入的书和读到的位置、自选壁纸、导入的音乐、其它世界。恢复前会先问一次，因为现有数据会被整份替换。歌单随软件发，重装不用重新导。"
                    ) {
                        Button {
                            exportAll()
                        } label: {
                            GroupedRow(
                                symbol: "square.and.arrow.up",
                                symbolTint: Theme.tint,
                                title: "导出全部数据"
                            )
                        }
                        .buttonStyle(.plain)

                        RowDivider()

                        Button {
                            showRestore = true
                        } label: {
                            GroupedRow(
                                symbol: "square.and.arrow.down",
                                symbolTint: Theme.IconTint.green,
                                title: "从备份恢复"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
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
        .confirmationDialog(
            "恢复这份备份？",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRestore
        ) { url in
            Button("恢复并覆盖现在全部数据", role: .destructive) {
                performRestore(url)
            }
            Button("取消", role: .cancel) { pendingRestore = nil }
        } message: { _ in
            Text("角色、聊天记录、备忘录、动态、世界书、我的身份、表情库和书架都会被这份备份替换，现在这份不会自动留副本。想留就先点上面的「导出全部数据」。")
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
            // 选完不立刻动手，先挂起等确认。
            pendingRestore = url
        }
    }

    private func performRestore(_ url: URL) {
        pendingRestore = nil
        do {
            let summary = try DataBackup.restore(from: url, context: context)
            world.reload()
            alertText = summary
        } catch {
            alertText = "恢复失败：\(error.localizedDescription)"
        }
    }
}
