import SwiftUI
import SwiftData

/// 群设置：群名、成员。
///
/// 从「角色详情 → 群成员」进来。之前这一行只是一段只读的「N 人」，
/// 想加个人只能回角色编辑器里手打成员名——名字打错一个字，那个人
/// 在提示词里就不存在了。这里改成点名字，名单直接写回 `membersNote`。
struct GroupMembersPage: View {
    @Bindable var character: Companion
    var world: WorldStore

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Companion.sortIndex), SortDescriptor(\Companion.createdAt)])
    private var companions: [Companion]

    @State private var nameDraft = ""
    @State private var showPicker = false
    @State private var pendingRemove: String?

    private var roster: [Companion] {
        GroupRoster.members(of: character, in: companions)
    }

    /// 名单上有、库里找不到的名字。老群是手打进去的，可能有这种。
    private var orphanNames: [String] {
        let found = Set(roster.map(\.name))
        return GroupRoster.names(from: character.membersNote).filter { !found.contains($0) }
    }

    /// 能加进来的：已经有角色的人，且不在这个群里。
    private var addable: [Companion] {
        let current = Set(GroupRoster.names(from: character.membersNote))
        return companions.filter {
            !$0.isGroup && !$0.isFeedOnly
                && $0.name != DefaultAssistant.name
                && !current.contains($0.name)
        }
    }

    var body: some View {
        AppPage(title: "群设置") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    nameSection
                    memberSection
                    footerSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear { nameDraft = character.name }
        .confirmationDialog(
            "把「\(pendingRemove ?? "")」移出群？",
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("移出群", role: .destructive) {
                if let name = pendingRemove { remove(name) }
                pendingRemove = nil
            }
            Button("取消", role: .cancel) { pendingRemove = nil }
        } message: {
            Text("只是不在这个群里说话。跟他的单聊、记忆、好感度都还在。")
        }
        .sheet(isPresented: $showPicker) {
            GroupAddMemberSheet(
                candidates: addable,
                onAdd: { names in
                    add(names)
                    showPicker = false
                },
                onCancel: { showPicker = false }
            )
        }
    }

    // MARK: - 群名

    private var nameSection: some View {
        GroupedSection("群名", footer: "改完直接生效，会话列表和顶栏都跟着换。") {
            TextField("群名", text: $nameDraft)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.tint)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
                .onSubmit(commitName)
        }
    }

    // MARK: - 成员

    private var memberSection: some View {
        GroupedSection(
            "成员 · \(GroupRoster.names(from: character.membersNote).count) 人",
            footer: "群里的每一句台词都按成员的名字拆开，各自用自己的设定、心情和头像。"
        ) {
            ForEach(roster) { person in
                memberRow(person)
                RowDivider()
            }

            ForEach(orphanNames, id: \.self) { name in
                orphanRow(name)
                RowDivider()
            }

            Button {
                showPicker = true
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.tint)
                        .frame(width: 28)

                    Text("加人")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.tint)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func memberRow(_ person: Companion) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            AvatarBubble(character: person, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)

                if !person.persona.isEmpty {
                    Text(person.persona.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            removeButton(person.name)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: 54)
    }

    private func orphanRow(_ name: String) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 17))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)

                Text("这个名字没有对应的角色，群里只会当成一个普通名字")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            removeButton(name)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: 54)
    }

    private func removeButton(_ name: String) -> some View {
        Button {
            pendingRemove = name
        } label: {
            Image(systemName: "minus.circle")
                .font(.system(size: 18))
                .foregroundStyle(Theme.brand.opacity(0.85))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerSection: some View {
        Text("不想要这个群了，在「信息」列表里长按它删除，聊天记录会一起清掉。")
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PhoneMetrics.Space.l)
    }

    // MARK: - 改动

    private func remove(_ name: String) {
        let next = GroupRoster.names(from: character.membersNote).filter { $0 != name }
        commit(members: next)
        Haptics.tap()
    }

    private func add(_ names: [String]) {
        var next = GroupRoster.names(from: character.membersNote)
        for name in names where !next.contains(name) {
            next.append(name)
        }
        commit(members: next)
        Haptics.tap()
    }

    private func commit(members: [String]) {
        character.membersNote = GroupRoster.note(from: members)
        try? context.save()
        // 世界状态里那张表要跟着换：不改的话，被移出的人还会继续
        // 收到这个群的记忆，单聊里也还会把群算成他在的地方。
        world.syncGroup(named: character.name, members: members)
    }

    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != character.name else {
            nameDraft = character.name
            return
        }
        // 改名要连世界状态一起搬：记忆、心情、好感度都以名字为键，
        // 只改 SwiftData 这边的话，群里的记忆当场断掉。
        let old = character.name
        character.name = trimmed
        try? context.save()
        world.renamePerson(from: old, to: trimmed)
    }
}

/// 加人。只列还没在群里的角色。
struct GroupAddMemberSheet: View {
    let candidates: [Companion]
    var onAdd: ([String]) -> Void
    var onCancel: () -> Void

    @State private var picked = Set<String>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navBar

                if candidates.isEmpty {
                    Text("没有可加的人。先去「信息」里新建一个角色，再回来加。")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .padding(PhoneMetrics.Space.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                } else {
                    List {
                        ForEach(candidates) { person in
                            Button {
                                if picked.contains(person.name) {
                                    picked.remove(person.name)
                                } else {
                                    picked.insert(person.name)
                                }
                            } label: {
                                HStack(spacing: PhoneMetrics.Space.s) {
                                    AvatarBubble(character: person, size: 34)

                                    Text(person.name)
                                        .font(.system(size: PhoneMetrics.FontSize.body))
                                        .foregroundStyle(AppSurface.light.label)

                                    Spacer(minLength: 0)

                                    Image(systemName: picked.contains(person.name)
                                        ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19))
                                        .foregroundStyle(picked.contains(person.name)
                                            ? Theme.tint : AppSurface.light.secondaryLabel.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(AppSurface.light.rowSurface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .environment(\.colorScheme, .light)
        }
    }

    private var navBar: some View {
        ZStack {
            Text("加人")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)

            HStack {
                Button("取消", action: onCancel)
                    .font(.system(size: 15))
                    .foregroundStyle(AppSurface.light.secondaryLabel)

                Spacer(minLength: 0)

                Button {
                    onAdd(candidates.map(\.name).filter { picked.contains($0) })
                } label: {
                    Text(picked.isEmpty ? "加入" : "加入 \(picked.count) 人")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(picked.isEmpty
                            ? AppSurface.light.secondaryLabel.opacity(0.4) : Theme.tint))
                }
                .buttonStyle(.plain)
                .disabled(picked.isEmpty)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(height: 46)
        .background(AppSurface.light.background)
    }
}
