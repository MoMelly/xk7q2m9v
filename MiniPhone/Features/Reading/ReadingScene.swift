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
    }

    // MARK: - 书架

    private var shelf: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.s) {
                ForEach(books) { book in
                    NavigationLink {
                        ReaderPage(book: book)
                    } label: {
                        row(book)
                    }
                    .buttonStyle(.plain)
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

/// 读书页。
///
/// 衬线正文、段落留白、进度按段落记。字号四档，存在本地，
/// 关了再开还是上次那个大小。
struct ReaderPage: View {
    @Bindable var book: ReadingBook

    @Environment(\.modelContext) private var context
    @AppStorage("reading.fontSize") private var fontSize: Double = 18

    private var paragraphs: [String] { book.paragraphs }

    var body: some View {
        AppPage(title: book.title, surface: .light) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .font(.system(size: fontSize, design: .serif))
                                .lineSpacing(9)
                                .foregroundStyle(AppSurface.light.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                                .onAppear { markRead(index) }
                        }

                        Text("读完了")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.top, PhoneMetrics.Space.xl)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, PhoneMetrics.Space.m)
                }
                .onAppear {
                    guard !paragraphs.isEmpty else { return }
                    let target = min(book.paragraphIndex, paragraphs.count - 1)
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach([16.0, 18.0, 20.0, 22.0], id: \.self) { size in
                        Button("\(Int(size)) 号") { fontSize = size }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .onDisappear {
            book.lastReadAt = Date()
            try? context.save()
        }
    }

    /// 只往前进不退：往回翻的时候不该把进度改回去。
    private func markRead(_ index: Int) {
        guard index > book.paragraphIndex else { return }
        book.paragraphIndex = index
        book.lastReadAt = Date()
    }
}
