import SwiftUI
import SwiftData

/// 读书页。
///
/// 原来是一条 `ScrollView` 往下滚：没有页，没有目录，翻页只是滚动。
/// 现在按真实可用高度切页，左右滑动翻页，右上角能开目录直接跳章。
struct ReaderPage: View {
    @Bindable var book: ReadingBook

    @Environment(\.modelContext) private var context

    @AppStorage("reading.fontSize") private var fontSize: Double = 18
    @AppStorage("reading.lineSpacing") private var lineSpacing: Double = 9
    @AppStorage("reading.paper") private var paperRaw = ReaderPaper.cream.rawValue
    /// 正文左右留白。原来写死 22，设置里改不了。
    @AppStorage("reading.margin") private var margin: Double = 22

    @State private var chapters: [BookChapter] = []
    @State private var chapterIndex = 0
    @State private var pages: [BookPage] = [BookPage(start: 0, text: "")]
    @State private var pageIndex = 0
    @State private var showChapters = false
    @State private var showSettings = false
    @State private var contentSize: CGSize = .zero
    @State private var prepared = false

    private var paper: ReaderPaper {
        ReaderPaper(rawValue: paperRaw) ?? .cream
    }

    /// 测量用的字体必须和渲染的一模一样，否则每页最后会多一行或者漏一行。
    private var uiFont: UIFont {
        UIFont(name: "Songti SC", size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
    }

    private var chapterTitle: String {
        guard chapters.indices.contains(chapterIndex) else { return "" }
        return chapters[chapterIndex].title
    }

    var body: some View {
        AppPage(title: book.title, surface: .light) {
            ZStack {
                paper.background.ignoresSafeArea()

                GeometryReader { proxy in
                    let size = CGSize(
                        width: max(proxy.size.width, 120),
                        height: max(proxy.size.height, 160)
                    )

                    TabView(selection: $pageIndex) {
                        ForEach(pages.indices, id: \.self) { index in
                            pageBody(pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onAppear { update(size) }
                    .onChange(of: size) { _, new in update(new) }
                }
                .padding(.horizontal, margin)
                .padding(.top, 6)
                .padding(.bottom, 44)
            }
            .overlay(alignment: .bottom) { footer }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showChapters = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("目录")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("排版")
            }
        }
        .sheet(isPresented: $showChapters) { chapterSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .onAppear(perform: prepare)
        .onChange(of: pageIndex) { _, new in markRead(new) }
        .onChange(of: fontSize) { _, _ in rebuild() }
        .onChange(of: lineSpacing) { _, _ in rebuild() }
        .onChange(of: margin) { _, _ in rebuild() }
        .onDisappear(perform: savePosition)
    }

    // MARK: - 页面

    private func pageBody(_ page: BookPage) -> some View {
        PageTextView(
            text: page.text,
            font: uiFont,
            lineSpacing: CGFloat(lineSpacing),
            ink: UIColor(paper.ink)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 点左右两侧翻页。真机上也是这么翻的：想翻就点，不想翻就滑。
        .overlay(alignment: .leading) { tapZone(forward: false) }
        .overlay(alignment: .trailing) { tapZone(forward: true) }
    }

    /// 边缘的点击区。只吃轻点，滑动照旧交给 TabView。
    private func tapZone(forward: Bool) -> some View {
        Color.clear
            .frame(width: 68)
            .contentShape(Rectangle())
            .onTapGesture { turnPage(forward: forward) }
            .accessibilityLabel(forward ? "下一页" : "上一页")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(min(pageIndex + 1, max(pages.count, 1))) / \(max(pages.count, 1))")
                .monospacedDigit()

            Spacer(minLength: 0)

            Button {
                showChapters = true
            } label: {
                HStack(spacing: 4) {
                    Text(chapterTitle)
                        .lineLimit(1)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(paper.ink.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 11))
        .foregroundStyle(paper.ink.opacity(0.4))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    // MARK: - 目录

    private var chapterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(chapters) { chapter in
                        Button {
                            jump(to: chapter)
                            showChapters = false
                        } label: {
                            HStack(spacing: PhoneMetrics.Space.s) {
                                Text(chapter.title)
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(chapter.id == chapterIndex ? Theme.tint : AppSurface.light.label)
                                    .lineLimit(1)

                                Spacer(minLength: PhoneMetrics.Space.xs)

                                if chapter.id == chapterIndex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.tint)
                                }
                            }
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: 46)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if chapter.id != chapters.last?.id {
                            RowDivider().padding(.leading, PhoneMetrics.Space.m)
                        }
                    }
                }
                .padding(.vertical, PhoneMetrics.Space.xs)
            }
            .background(AppSurface.light.background)
            .navigationTitle("目录 · \(chapters.count) 章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { showChapters = false }
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.medium, .large])
    }

    private var settingsSheet: some View {
        ReaderSettingsSheet(
            fontSize: $fontSize,
            lineSpacing: $lineSpacing,
            paperRaw: $paperRaw,
            margin: $margin
        )
    }

    // MARK: - 分页

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        chapters = BookPaginator.chapters(in: book.paragraphs)
        chapterIndex = chapters.lastIndex { $0.start <= book.paragraphIndex } ?? 0
        rebuild(keep: book.paragraphIndex)
    }

    private func update(_ size: CGSize) {
        let rounded = CGSize(width: floor(size.width), height: floor(size.height))
        guard rounded != contentSize else { return }
        contentSize = rounded
        rebuild()
    }

    private func rebuild(keep paragraph: Int? = nil) {
        guard contentSize.width > 1, contentSize.height > 1 else { return }

        if chapters.isEmpty {
            chapters = BookPaginator.chapters(in: book.paragraphs)
        }
        guard !chapters.isEmpty else { return }

        let safeChapter = min(max(chapterIndex, 0), chapters.count - 1)
        chapterIndex = safeChapter
        let chapter = chapters[safeChapter]
        let all = book.paragraphs
        let upper = min(chapter.end, all.count)
        guard chapter.start < upper else {
            pages = [BookPage(start: chapter.start, text: "")]
            pageIndex = 0
            return
        }

        pages = BookPaginator.pages(
            paragraphs: all,
            range: chapter.start..<upper,
            size: contentSize,
            font: uiFont,
            lineSpacing: CGFloat(lineSpacing)
        )

        let target = paragraph ?? book.paragraphIndex
        pageIndex = min(BookPaginator.pageIndex(containing: target, in: pages), pages.count - 1)
    }

    private func jump(to chapter: BookChapter) {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        chapterIndex = index
        rebuild(keep: chapter.start)
    }

    /// 点边缘翻一页。章末再点就进下一章，章首再点回上一章最后一页。
    private func turnPage(forward: Bool) {
        let target = forward ? pageIndex + 1 : pageIndex - 1
        if pages.indices.contains(target) {
            withAnimation(.easeOut(duration: 0.18)) { pageIndex = target }
            return
        }

        let next = forward ? chapterIndex + 1 : chapterIndex - 1
        guard chapters.indices.contains(next) else { return }
        chapterIndex = next
        rebuild(keep: chapters[next].start)
        pageIndex = forward ? 0 : max(pages.count - 1, 0)
    }

    private func markRead(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        book.paragraphIndex = pages[index].start
        book.lastReadAt = Date()
    }

    private func savePosition() {
        book.lastReadAt = Date()
        try? context.save()
    }
}
