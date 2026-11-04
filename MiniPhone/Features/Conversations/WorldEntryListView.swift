import SwiftUI
import SwiftData

/// 设定集：关键词触发的背景设定。
///
/// 这是酒馆「世界书」的最小可用版——只有关键词和内容，没有插入位置、
/// 递归触发、概率这些参数。实际用起来，九成场景只需要「提到 X 就把 Y 补进去」。
struct WorldEntryListView: View {
    let character: Companion

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\WorldEntry.createdAt, order: .reverse)])
    private var allEntries: [WorldEntry]

    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false
    @State private var keywords = ""
    @State private var content = ""

    private var entries: [WorldEntry] {
        allEntries.filter { $0.characterUID == character.uid }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Section {
                        Text("还没有条目。\n\n比如关键词填「灯塔」，内容写「港口东侧那座白色灯塔三年前就废弃了，灯还亮着」。之后聊天里提到灯塔，这段就会自动进提示词。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.keywordList.joined(separator: " · "))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.retroGreen)

                                Text(entry.content)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                context.delete(entries[index])
                            }
                            try? context.save()
                        }
                    } footer: {
                        Text("向左滑可以删除。")
                    }
                }
            }
            .navigationTitle("设定集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        keywords = ""
                        content = ""
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                addSheet
            }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("关键词，逗号分隔", text: $keywords)
                } footer: {
                    Text("聊天内容里出现任一关键词，下面的内容就会被注入提示词。")
                }

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                } header: {
                    Text("内容")
                }
            }
            .navigationTitle("新设定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmedKeywords = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedKeywords.isEmpty, !trimmedContent.isEmpty else { return }

                        let entry = WorldEntry(
                            characterUID: character.uid,
                            keywords: trimmedKeywords,
                            content: trimmedContent
                        )
                        context.insert(entry)
                        try? context.save()
                        showAdd = false
                    }
                    .disabled(
                        keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
