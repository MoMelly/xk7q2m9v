import PhotosUI
import SwiftData
import SwiftUI

/// 表情管理。
///
/// 三件事：批量传图、给表情改备注、按分组归堆。
/// 备注名就是提示词里那个名字——上传上来的图没有名字，
/// 不补一个角色就没法「用」它们，只能当摆设。
struct StickerPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StickerItem.createdAt, order: .forward) private var stickers: [StickerItem]

    @State private var selectedGroup: String?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var editing: StickerItem?
    @State private var isImporting = false
    @State private var alertText: String?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 4
    )

    private var groups: [String] {
        var seen: [String] = []
        for sticker in stickers where !sticker.group.isEmpty && !seen.contains(sticker.group) {
            seen.append(sticker.group)
        }
        return seen
    }

    private var visible: [StickerItem] {
        guard let selectedGroup else { return stickers }
        return stickers.filter { $0.group == selectedGroup }
    }

    var body: some View {
        AppPage(title: "表情") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    groupBar
                    actionSection
                    gridSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear {
            StickerLibrary.shared.reload(context: context)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importStickers(items) }
        }
        .sheet(item: $editing) { sticker in
            StickerEditorSheet(sticker: sticker) {
                delete(sticker)
            }
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

    // MARK: - 分组

    private var groupBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "全部", count: stickers.count, active: selectedGroup == nil) {
                    selectedGroup = nil
                }

                ForEach(groups, id: \.self) { group in
                    let count = stickers.filter { $0.group == group }.count
                    chip(title: group, count: count, active: selectedGroup == group) {
                        selectedGroup = group
                    }
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
        }
    }

    private func chip(title: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: active ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .opacity(0.7)
            }
            .foregroundStyle(active ? .white : Theme.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(active ? Theme.brand : Theme.cardSurface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 上传

    private var actionSection: some View {
        GroupedSection(
            "添加",
            footer: "备注名会写进提示词，角色只能看到有名字的表情。分组只是方便你整理。"
        ) {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 0,
                matching: .images,
                photoLibrary: .shared()
            ) {
                GroupedRow(
                    symbol: "square.and.arrow.down",
                    symbolTint: Theme.IconTint.purple,
                    title: isImporting ? "正在导入…" : "批量导入图片"
                )
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
        }
    }

    // MARK: - 网格

    private var gridSection: some View {
        GroupedSection(
            "已有表情",
            footer: "点一个改备注名或换分组。上传的表情没改名字之前，角色不会用它。"
        ) {
            if visible.isEmpty {
                Text("还没有表情。上面导一批进来，或者切到「全部」看看内置那套。")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(visible) { sticker in
                        Button {
                            editing = sticker
                        } label: {
                            VStack(spacing: 4) {
                                StickerView(item: sticker, size: 64)
                                Text(sticker.name)
                                    .font(.system(size: PhoneMetrics.FontSize.caption))
                                    .foregroundStyle(Theme.label)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
        }
    }

    // MARK: - 数据

    @MainActor
    private func importStickers(_ items: [PhotosPickerItem]) async {
        isImporting = true
        var added = 0
        var failed = 0

        for (offset, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                failed += 1
                continue
            }
            guard let fileName = try? StickerStorage.save(image: image) else {
                failed += 1
                continue
            }
            context.insert(
                StickerItem(
                    name: "表情\(stickers.count + offset + 1)",
                    group: selectedGroup ?? "",
                    fileName: fileName
                )
            )
            added += 1
        }

        try? context.save()
        StickerLibrary.shared.reload(context: context)
        pickerItems = []
        isImporting = false

        var text = "导入 \(added) 个。"
        if failed > 0 { text += "\(failed) 张读不出来，已跳过。" }
        text += "记得一个个改成能读的名字。"
        alertText = text
    }

    private func delete(_ sticker: StickerItem) {
        StickerStorage.delete(fileName: sticker.fileName)
        context.delete(sticker)
        try? context.save()
        StickerLibrary.shared.reload(context: context)
    }
}
