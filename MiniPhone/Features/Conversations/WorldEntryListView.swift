import SwiftUI
import SwiftData

/// 设定集：背景设定。
///
/// 两档：
/// - 常驻：每轮都进提示词。住处、工作、家里有谁这种基本盘，聊什么都得知道；
/// - 关键词：提到某个词才注入。灯塔、旧伤、那只猫的名字，属于用到才想起来的细节。
///
/// 酒馆里还有插入位置、递归触发、概率这些参数，这里都不做：
/// 实际用起来九成场景就是「一直知道」和「提到才想起」两种。
struct WorldEntryListView: View {
    let character: Companion

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\WorldEntry.createdAt, order: .reverse)])
    private var allEntries: [WorldEntry]

    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false
    @State private var keywords = ""
    @State private var content = ""
    @State private var alwaysOn = false

    private var entries: [WorldEntry] {
        allEntries.filter { $0.characterUID == character.uid }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Section {
                        Text("还没有条目。\n\n比如常驻一条「你们住在城西，他每天骑车上下班」——不管聊什么，角色都知道这件事。\n\n也可以做成关键词条目：关键词填「灯塔」，内容写「港口东侧那座白色灯塔三年前就废弃了，灯还亮着」，之后聊天里提到灯塔，这段才会补进去。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                context.delete(entries[index])
                            }
                            try? context.save()
                        }
                    } footer: {
                        Text("常驻条目每轮都会带上，别写太长；关键词条目向左滑可以删除。")
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
                        alwaysOn = false
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

    private func row(_ entry: WorldEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(entry.alwaysOn ? "常驻" : entry.keywordList.joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(entry.alwaysOn ? Theme.IconTint.rose : Theme.retroGreen)

                if entry.alwaysOn && !entry.keywordList.isEmpty {
                    Text("也在 \(entry.keywordList.joined(separator: "、")) 时")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text(entry.content)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("常驻", isOn: $alwaysOn)
                } footer: {
                    Text(alwaysOn
                         ? "每轮都会带上。基本设定写在这里：你们住哪儿、他做什么、家里有谁。"
                         : "聊天内容里出现关键词才注入，适合用到才想起来的细节。")
                }

                Section {
                    TextField("关键词，逗号分隔", text: $keywords)
                } footer: {
                    Text(alwaysOn
                         ? "常驻条目可以不填关键词。填了也只是给列表看，不影响注入。"
                         : "聊天内容里出现任一关键词，下面的内容就会被注入提示词。")
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
                        // 关键词条目没有词就永远不会命中，存下来是死数据。
                        guard !trimmedContent.isEmpty else { return }
                        guard alwaysOn || !trimmedKeywords.isEmpty else { return }

                        let entry = WorldEntry(
                            characterUID: character.uid,
                            keywords: trimmedKeywords,
                            content: trimmedContent,
                            alwaysOn: alwaysOn
                        )
                        context.insert(entry)
                        try? context.save()
                        showAdd = false
                    }
                    .disabled(saveDisabled)
                }
            }
        }
    }

    private var saveDisabled: Bool {
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasKeywords = !keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !hasContent || (!alwaysOn && !hasKeywords)
    }
}
