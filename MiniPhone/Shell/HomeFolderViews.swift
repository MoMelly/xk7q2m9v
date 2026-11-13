import SwiftUI

/// 文件夹图标：一个磨砂方块里摆前几个 App 的小图标。
///
/// 不画白底大卡片：真机的文件夹是半透明的，能透出壁纸；
/// 画成实心白块会和旁边那些彩色图标分不清谁是谁。
struct FolderTile: View {
    let apps: [PhoneApp]
    var size: CGFloat = PhoneMetrics.iconSize

    private var cornerRadius: CGFloat { size * 0.224 }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
            }
            .overlay { miniGrid }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var miniGrid: some View {
        let inset = size * 0.13
        let gap = size * 0.06
        let side = size - inset * 2
        let cell = (side - gap * 2) / 3

        return VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < min(apps.count, 9) {
                            AppIconTile(app: apps[index], size: cell, showsLabel: false)
                        } else {
                            Color.clear.frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }
}

/// 打开文件夹之后的浮层。
///
/// 用 sheet 而不是原地展开：原地展开要把整个网格重排，退出来的时候
/// 图标会飞回去，看着像动画出错。浮层只盖住它自己。
struct FolderPanel: View {
    let folderID: String
    let title: String
    let appIDs: [String]
    let onOpen: (PhoneApp) -> Void
    let onRename: (String) -> Void
    let onUngroup: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var renaming = false

    private var apps: [PhoneApp] {
        appIDs.compactMap { id in
            AppCatalog.all.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    GroupedSection {
                        LazyVGrid(columns: gridColumns, spacing: PhoneMetrics.Space.l) {
                            ForEach(apps) { app in
                                Button {
                                    onOpen(app)
                                } label: {
                                    VStack(spacing: 6) {
                                        AppIconTile(app: app, showsLabel: false)
                                        Text(app.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.label)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(PhoneMetrics.Space.m)
                    }

                    GroupedSection(
                        footer: "拆开之后里面的图标会铺回主屏，文件夹就没了。"
                    ) {
                        Button {
                            onUngroup()
                            dismiss()
                        } label: {
                            GroupedRow(
                                symbol: "square.split.2x2",
                                symbolTint: Theme.IconTint.teal,
                                title: "拆开文件夹"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(Theme.groupedBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("改个名") {
                        draft = title
                        renaming = true
                    }
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("文件夹名字", isPresented: $renaming) {
                TextField("名字", text: $draft)
                Button("改") { onRename(draft) }
                Button("取消", role: .cancel) {}
            }
        }
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .presentationDetents([.medium, .large])
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: PhoneMetrics.Space.l, alignment: .top), count: 4)
    }
}
