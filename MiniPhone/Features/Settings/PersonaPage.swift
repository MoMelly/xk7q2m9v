import SwiftUI
import SwiftData

/// 我的人设。
///
/// 一个人在这部手机里可以有多个身份：用小号去逗某个角色、换个名字重新认识同一个人。
/// 这一页只管「我是谁」；角色以为在跟谁说话，由每个会话自己选。
struct PersonaPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    @State private var editing: UserProfile?
    @State private var isCreating = false

    var body: some View {
        AppPage(title: "我的人设", surface: .light) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        footer: "换身份不换记忆：角色记住的事挂在会话上，人设只决定他以为在跟谁说话。"
                    ) {
                        ForEach(profiles) { profile in
                            if profile.uid != profiles.first?.uid {
                                RowDivider()
                            }

                            Button {
                                editing = profile
                            } label: {
                                row(profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    GroupedSection {
                        Button {
                            isCreating = true
                        } label: {
                            GroupedRow(
                                symbol: "person.badge.plus",
                                symbolTint: Theme.IconTint.indigo,
                                title: "新建一个身份",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .sheet(item: $editing) { profile in
            PersonaEditor(profile: profile, onClose: { editing = nil })
        }
        .sheet(isPresented: $isCreating) {
            PersonaEditor(profile: nil, onClose: { isCreating = false })
        }
    }

    private func row(_ profile: UserProfile) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            ZStack {
                Circle()
                    .fill(Theme.IconTint.indigo.opacity(0.14))
                Text(String(profile.name.prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.IconTint.indigo)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PhoneMetrics.Space.xxs) {
                    Text(profile.name)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)

                    if profile.isDefault {
                        Text("默认")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.IconTint.indigo)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Theme.IconTint.indigo.opacity(0.12))
                            )
                    }
                }

                Text(detail(profile))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.6))
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    private func detail(_ profile: UserProfile) -> String {
        let signature = profile.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if !signature.isEmpty { return signature }
        let bio = profile.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bio.isEmpty { return bio }
        return "还没写介绍"
    }
}

/// 新建 / 编辑一个身份。
struct PersonaEditor: View {
    let profile: UserProfile?
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var signature = ""
    @State private var bio = ""
    @State private var tags = ""
    @State private var isDefault = false
    @State private var loaded = false

    private var isNew: Bool { profile == nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection {
                        fieldRow("名字") {
                            TextField("我", text: $name)
                                .multilineTextAlignment(.trailing)
                        }

                        RowDivider()

                        fieldRow("一句话签名") {
                            TextField("随便写一句", text: $signature)
                                .multilineTextAlignment(.trailing)
                        }

                        RowDivider()

                        fieldRow("标签") {
                            TextField("用逗号分开", text: $tags)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    GroupedSection(footer: "介绍会进提示词。写上年龄、职业、跟 TA 什么关系，角色说话会更准。") {
                        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xxs) {
                            Text("介绍")
                                .font(.system(size: PhoneMetrics.FontSize.footnote))
                                .foregroundStyle(AppSurface.light.secondaryLabel)

                            TextField("比如：大二，住校，晚上十一点熄灯", text: $bio, axis: .vertical)
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .lineLimit(3...6)
                        }
                        .padding(PhoneMetrics.Space.m)
                    }

                    GroupedSection {
                        Toggle(isOn: $isDefault) {
                            Text("新会话默认用这个身份")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(AppSurface.light.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    if let profile, !isNew {
                        GroupedSection {
                            Button(role: .destructive) {
                                let gone = profile.uid.uuidString
                                UserProfileBook.delete(profile, in: context)
                                // 正站在这个身份上就别留在原地：它的记录跟着人走了，
                                // 停在上面只会看到一整屏空对话。
                                IdentityScope.shared.fallBackIfNeeded(deletedUID: gone)
                                onClose()
                            } label: {
                                GroupedRow(
                                    symbol: "trash.fill",
                                    symbolTint: Theme.IconTint.gray,
                                    title: "删掉这个身份"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .navigationTitle(isNew ? "新建身份" : "编辑身份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!canSave)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .onAppear(perform: load)
    }

    private func fieldRow<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
                .frame(width: 92, alignment: .leading)

            trailing()
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.single)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let profile else {
            isDefault = UserProfileBook.all(in: context).isEmpty
            return
        }
        name = profile.name
        signature = profile.signature
        bio = profile.bio
        tags = profile.tagsRaw
        isDefault = profile.isDefault
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if let profile {
            profile.name = cleanName
            profile.signature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.tagsRaw = tags
        } else {
            let created = UserProfile(
                name: cleanName,
                signature: signature.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                tagsRaw: tags
            )
            context.insert(created)
            if isDefault {
                UserProfileBook.makeDefault(created, in: context)
            }
        }

        if let profile, isDefault {
            UserProfileBook.makeDefault(profile, in: context)
        }
        try? context.save()
        onClose()
    }
}

/// 某个会话用哪个身份。
struct PersonaPickerPage: View {
    @Bindable var character: Companion
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    var body: some View {
        AppPage(title: "用哪个身份", surface: .light) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        footer: "只影响这一段会话。换回默认身份，角色说话的口吻也会跟着回去。"
                    ) {
                        row(
                            title: "用默认身份",
                            subtitle: defaultName,
                            selected: character.personaUID.isEmpty
                        ) {
                            character.personaUID = ""
                            try? context.save()
                        }

                        ForEach(profiles) { profile in
                            RowDivider()
                            row(
                                title: profile.name,
                                subtitle: profile.signature.isEmpty ? "没有签名" : profile.signature,
                                selected: character.personaUID == profile.uid.uuidString
                            ) {
                                character.personaUID = profile.uid.uuidString
                                try? context.save()
                            }
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var defaultName: String {
        let name = profiles.first(where: { $0.isDefault })?.name ?? profiles.first?.name ?? "我"
        return "现在是「\(name)」"
    }

    private func row(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PhoneMetrics.Space.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)
                    Text(subtitle)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tint)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
