import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 阅读：把自己手上的 txt 导进来读。
///
/// 只收纯文本。txt 本来就没有排版，硬套章节解析遇到格式不规整的书会把正文切碎，
/// 所以按段落切、按段落存进度——换字号也不会让进度跑位。
struct ReadingScene: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \ReadingBook.lastReadAt, order: .reverse) private var books: [ReadingBook]

    @State private var showImporter = false
    @State private var importError: String?
    /// 等二次确认的删除目标。
    @State private var deleteTarget: ReadingBook?

    var body: some View {
        AppScreen(
            title: "阅读",
            surface: .light,
            onClose: onClose,
            trailingSymbol: "plus",
            trailingAction: { showImporter = true }
        ) {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    shelf
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(
            "导入失败",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert(
            "删除这本书？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { book in
            Button("删除", role: .destructive) { performDelete(book) }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: { book in
            Text("「\(book.title)」和读到哪儿都会删掉，书里的文字不会留在本机。")
        }
    }

    private func performDelete(_ book: ReadingBook) {
        context.delete(book)
        try? context.save()
    }

    // MARK: - 书架

    private var shelf: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.s) {
                ForEach(books) { book in
                    HStack(spacing: 0) {
                        NavigationLink {
                            ReaderPage(book: book)
                        } label: {
                            row(book)
                        }
                        .buttonStyle(.plain)

                        // 书上原来没有任何删除入口。放在行尾，比长按菜单好找。
                        Menu {
                            Button(role: .destructive) {
                                deleteTarget = book
                            } label: {
                                Label("删除这本书", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppSurface.light.secondaryLabel)
                                .frame(width: 40, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.top, PhoneMetrics.Space.s)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    private func row(_ book: ReadingBook) -> some View {
        HStack(spacing: PhoneMetrics.Space.m) {
            // 书脊：不画封面图，用一条窄色块代表这本书。
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.IconTint.orange.opacity(0.55))
                .frame(width: 6, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(1)

                Text(book.summary)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)

                ProgressView(value: book.progress)
                    .tint(Theme.IconTint.orange)
                    .frame(height: 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.5))
        }
        .padding(PhoneMetrics.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard(cornerRadius: PhoneMetrics.Radius.card)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "books.vertical")
                .font(.system(size: 30, weight: .light))

            Text("书架是空的")
                .font(.system(size: PhoneMetrics.FontSize.sub))

            Text("右上角加号，把手机里的 txt 导进来。读到哪里会自己记住。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.xl)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            importError = "这个文件读不出来，可能没给访问权限。"
            return
        }
        guard let text = decode(data) else {
            importError = "文字的编码认不出来。用记事本另存成 UTF-8 再导一次。"
            return
        }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            importError = "文件里没有文字。"
            return
        }

        let name = url.deletingPathExtension().lastPathComponent
        let book = ReadingBook(title: name.isEmpty ? "未命名" : name, body: clean)
        context.insert(book)
        try? context.save()
    }

    /// 中文 txt 有相当一部分是 GB18030。UTF-8 认不下来就试它，最后再试 UTF-16。
    private func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }

        let gb = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        if let text = String(data: data, encoding: String.Encoding(rawValue: gb)) { return text }

        return String(data: data, encoding: .utf16)
    }
}
