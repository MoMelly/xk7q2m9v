import SwiftUI
import SwiftData

/// 备忘录。
///
/// 这是「我的」备忘录：自己写、自己改、自己删。
/// 角色记得的东西不在这里——那是角色的记忆，只出现在角色详情里，
/// 而且是只读的。两者混在一个列表里，会分不清哪条是自己写的。
struct NotesScene: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\NoteItem.updatedAt, order: .reverse)])
    private var notes: [NoteItem]

    @State private var query = ""
    @State private var editing: NoteItem?
    @State private var showNewNote = false

    private var filtered: [NoteItem] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return notes }
        return notes.filter {
            $0.title.lowercased().contains(key) || $0.body.lowercased().contains(key)
        }
    }

    private var pinned: [NoteItem] {
        filtered.filter(\.isPinned)
    }

    private var others: [NoteItem] {
        filtered.filter { !$0.isPinned }
    }

    var body: some View {
        AppScreen(
            title: "备忘录",
            onClose: onClose,
            trailingSymbol: "square.and.pencil",
            trailingAction: { showNewNote = true }
        ) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    searchField

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        if !pinned.isEmpty {
                            noteSection("置顶", notes: pinned)
                        }
                        noteSection(pinned.isEmpty ? "所有备忘录" : "备忘录", notes: others)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .sheet(item: $editing) { note in
            NoteEditorPage(note: note)
        }
        .sheet(isPresented: $showNewNote) {
            NoteEditorPage(note: nil)
        }
    }

    // MARK: - 搜索

    private var searchField: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)

            ZStack(alignment: .leading) {
                // 外壳是深色模式，TextField 的占位色会跟着变浅，落在这块灰底上读不出来。
                if query.isEmpty {
                    Text("搜索")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.secondaryLabel)
                }
                TextField("", text: $query)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.tint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.secondaryLabel.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.s)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                .fill(Theme.separator.opacity(0.22))
        )
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    // MARK: - 列表

    private func noteSection(_ title: String, notes: [NoteItem]) -> some View {
        GroupedSection(title) {
            if notes.isEmpty {
                Text("这个分组是空的")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            } else {
                ForEach(notes) { note in
                    Button {
                        editing = note
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)

                    if note.id != notes.last?.id {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func noteRow(_ note: NoteItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.IconTint.orange)
                }

                Text(note.displayTitle)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text(TimeFormat.shortDate(note.updatedAt))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)

                Text(note.previewText.isEmpty ? "没有更多内容" : note.previewText)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "note.text")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.7))

            Text(query.isEmpty ? "还没有备忘录" : "没有匹配的备忘录")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)

            if query.isEmpty {
                Button("写第一条") { showNewNote = true }
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                    .foregroundStyle(Theme.tint)
                    .buttonStyle(.plain)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// 新建或编辑一条备忘录。
///
/// 用 sheet 而不是 push：系统备忘录也是从下往上滑出来的编辑页，
/// 而且这样不必在列表页塞一条 NavigationLink 的空转分支。
struct NoteEditorPage: View {
    let note: NoteItem?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draftTitle = ""
    @State private var draftBody = ""

    private var hasContent: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("标题", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.label)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.top, PhoneMetrics.Space.m)

                TextEditor(text: $draftBody)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.tint)
                    .padding(.horizontal, PhoneMetrics.Space.s)
                    .padding(.top, PhoneMetrics.Space.xs)
                    .overlay(alignment: .topLeading) {
                        if draftBody.isEmpty {
                            Text("写点什么")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                                .padding(.horizontal, PhoneMetrics.Space.m + 1)
                                .padding(.top, PhoneMetrics.Space.s)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .navigationTitle(note == nil ? "新备忘录" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("存储") { commit() }
                        .disabled(!hasContent)
                }
            }
            .environment(\.colorScheme, .light)
        }
        .onAppear {
            draftTitle = note?.title ?? ""
            draftBody = note?.body ?? ""
        }
    }

    private func commit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)

        if let note {
            note.title = title
            note.body = body
            note.updatedAt = Date()
        } else {
            let item = NoteItem(title: title, body: body)
            context.insert(item)
        }

        try? context.save()
        dismiss()
    }
}
