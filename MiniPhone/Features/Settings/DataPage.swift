import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 数据与备份。
struct DataPage: View {
    @Environment(\.modelContext) private var context
    @Environment(WorldStore.self) private var world

    @State private var shareItem: ShareItem?
    @State private var showRestore = false
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
                        footer: "导出的是一个文件夹：data.json、world-state.json，加上视频壁纸。恢复时选文件夹或里面的 json 都行。歌单随软件发，重装不用重新导。"
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
            do {
                let summary = try DataBackup.restore(from: url, context: context)
                world.reload()
                alertText = summary
            } catch {
                alertText = "恢复失败：\(error.localizedDescription)"
            }
        }
    }
}
