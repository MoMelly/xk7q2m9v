import SwiftUI

/// 备忘录。
///
/// 结构照系统备忘录：搜索框在最上，下面是文件夹列表，点进去才是笔记。
/// 这里的「文件夹」是一个人，里面装着它跨会话记住的事——数据沿用
/// `WorldState.people.facts`，不另造一份，单聊和群聊读的是同一批。
struct NotesScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var query = ""

    private var folders: [PersonMemory] {
        let people = world.state.people.filter { !$0.facts.isEmpty }
        guard !query.isEmpty else {
            return people.sorted { $0.facts.count > $1.facts.count }
        }
        let key = query.lowercased()
        return people.filter { person in
            person.name.lowercased().contains(key)
                || person.facts.contains { $0.text.lowercased().contains(key) }
        }
    }

    var body: some View {
        AppScreen(title: "备忘录", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    searchField
                    folderSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
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

    // MARK: - 文件夹

    @ViewBuilder
    private var folderSection: some View {
        if folders.isEmpty {
            Text(query.isEmpty ? "还没有记住任何事。聊过之后，值得留下的会被记到这里。" : "没有匹配的备忘录")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PhoneMetrics.Space.m)
        } else {
            GroupedSection(
                query.isEmpty ? "文件夹" : "搜索结果",
                footer: query.isEmpty ? "每一份是一个人。它说过的话、答应过的事都记在这里，不会因为换了会话就忘掉。" : nil
            ) {
                ForEach(folders) { person in
                    NavigationLink {
                        NoteListPage(person: person)
                    } label: {
                        GroupedRow(
                            symbol: "folder.fill",
                            symbolTint: Theme.IconTint.orange,
                            title: person.name,
                            value: "\(person.facts.count)",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    if person.id != folders.last?.id {
                        RowDivider()
                    }
                }
            }
        }
    }
}

/// 一个人名下的全部笔记。
struct NoteListPage: View {
    let person: PersonMemory

    private var notes: [PersonFact] {
        person.facts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        AppPage(title: person.name) {
            ScrollView {
                GroupedSection(footer: "记的是原话或明确的结论，不是概括。") {
                    if notes.isEmpty {
                        Text("这个文件夹还是空的")
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(PhoneMetrics.Space.m)
                    } else {
                        ForEach(notes) { fact in
                            GroupedRow(
                                title: fact.text,
                                subtitle: "\(fact.sourceName) · \(TimeFormat.callTime(fact.createdAt))"
                            )
                            .padding(.vertical, PhoneMetrics.Space.xs)

                            if fact.id != notes.last?.id {
                                RowDivider()
                            }
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
            }
        }
    }
}
