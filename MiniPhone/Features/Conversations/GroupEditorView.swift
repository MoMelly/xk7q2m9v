import SwiftUI
import SwiftData

/// 新建群聊。
///
/// 群不是一种新数据：它就是 `Companion` 上 `isGroup = true` 的那一条，
/// 成员写成用顿号隔开的名字。所以这里只做三件事——起名、挑人、把名字串写对。
///
/// 加这个入口之前，建群得去角色编辑器里打开「群聊」开关，再手打一串成员名。
/// 名字打错一个字，提示词里那个人就不存在了，界面上也不报错。
struct GroupEditorView: View {
    var onCreate: (Companion) -> Void
    var onCancel: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Companion.sortIndex), SortDescriptor(\Companion.createdAt)])
    private var companions: [Companion]
    @Query(sort: \UserProfile.createdAt, order: .forward)
    private var profiles: [UserProfile]

    @State private var name = ""
    @State private var picked = Set<String>()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 能拉进群的人。群、西瓜皮里的路人作者、内置小助手都不算；
    /// 其余角色和「我的人设」里的其它人排在同一张名单里，不分开列。
    private var candidates: [GroupPerson] {
        GroupPeople.candidates(roster: companions, profiles: profiles)
    }

    /// 同名会撞世界状态：群和人在那张表里都以名字为键。
    private var nameTaken: Bool {
        !trimmedName.isEmpty
            && (companions.contains { $0.name == trimmedName }
                || profiles.contains { $0.name == trimmedName })
    }

    private var canCreate: Bool {
        !trimmedName.isEmpty && !nameTaken && !picked.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(spacing: PhoneMetrics.Space.section) {
                        nameCard
                        memberCard
                    }
                    .padding(.top, PhoneMetrics.Space.m)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .environment(\.colorScheme, .light)
        }
    }

    // MARK: - 顶栏

    private var navBar: some View {
        ZStack {
            Text("新建群聊")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)

            HStack {
                Button("取消", action: onCancel)
                    .font(.system(size: 15))
                    .foregroundStyle(AppSurface.light.secondaryLabel)

                Spacer(minLength: 0)

                Button(action: create) {
                    Text("建群")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(canCreate ? Theme.tint : AppSurface.light.secondaryLabel.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(height: 46)
        .background(AppSurface.light.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
        }
    }

    // MARK: - 群名

    private var nameCard: some View {
        GroupedSection(
            "群名",
            footer: nameTaken ? "已经有同名的会话了，换一个名字。" : nil
        ) {
            TextField("比如：周末饭局", text: $name)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.tint)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    // MARK: - 成员

    private var memberCard: some View {
        GroupedSection(
            "成员",
            footer: picked.isEmpty
                ? "下面是能进群说话的人。想加一个还没有的，先给他建个角色，或在「我的人设」里加一个人。"
                : "已选 \(picked.count) 人。名字进群以后还能改，各人的设定、记忆和好感度还是他自己那一份。"
        ) {
            if candidates.isEmpty {
                Text("还没有可以加进来的人。先建一个角色，或在「我的人设」里加一个人，再回来建群。")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.vertical, PhoneMetrics.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, person in
                    if index > 0 { RowDivider() }
                    row(person)
                }
            }
        }
    }

    private func row(_ person: GroupPerson) -> some View {
        Button {
            if picked.contains(person.name) {
                picked.remove(person.name)
            } else {
                picked.insert(person.name)
            }
            Haptics.tap()
        } label: {
            HStack(spacing: PhoneMetrics.Space.s) {
                person.avatar(size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)

                    if !person.detail.isEmpty {
                        Text(person.detail.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: picked.contains(person.name) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(picked.contains(person.name) ? Theme.tint : AppSurface.light.secondaryLabel.opacity(0.5))
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 落库

    private func create() {
        guard canCreate else { return }

        // 按名单顺序取，不按点击顺序：同一个人建两次群，
        // 成员顺序应该一致，提示词里的排列也才稳定。
        let names = candidates.map(\.name).filter { picked.contains($0) }
        // 排序排在现有角色前面：刚建的群在会话列表最上面，
        // 和「新消息往上顶」的直觉一致。
        let first = (companions.map(\.sortIndex).min() ?? 0) - 1

        let group = Companion(
            name: trimmedName,
            persona: "",
            greeting: "",
            isGroup: true,
            membersNote: GroupRoster.note(from: names),
            sortIndex: first
        )
        group.lastMessageAt = Date()
        context.insert(group)
        try? context.save()

        // 世界状态里也存一份：单聊时才查得到「他还在哪些群里」。
        WorldStore.shared.syncGroup(named: group.name, members: names)

        Haptics.tap()
        onCreate(group)
    }
}
