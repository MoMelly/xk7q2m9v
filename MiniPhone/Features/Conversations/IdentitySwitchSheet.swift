import SwiftUI
import SwiftData

/// 切换身份。
///
/// 身份不是「同一个人换个称呼」：换成新身份之后，同一个角色对他一无所知，
/// 信息列表里每个联系人都还在，但一条消息都没有，开口是从头认识。
/// 切回来，原来那一段原封不动就在那儿。
struct IdentitySwitchSheet: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt, order: .forward) private var profiles: [UserProfile]

    @State private var creating = false

    /// 当前身份在列表里对应哪一行。空串是默认身份，落在被标成默认的那一个上。
    private var activeScope: String {
        let uid = IdentityScope.storedUID
        if !uid.isEmpty, profiles.contains(where: { $0.uid.uuidString == uid }) {
            return uid
        }
        return ""
    }

    private var activeName: String {
        if let matched = profiles.first(where: { $0.uid.uuidString == activeScope }) {
            return matched.name
        }
        return profiles.first(where: { $0.isDefault })?.name ?? profiles.first?.name ?? "我"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    header

                    GroupedSection(
                        footer: "切换之后，信息里每个联系人都还在，但记录是空的——他认识的是这个人，不是上一个人。换回来，原来那段对话原样都在。"
                    ) {
                        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                            if index > 0 { RowDivider() }
                            row(profile)
                        }
                    }

                    GroupedSection(footer: "新建的身份会有一份自己的记忆：同一件事，角色对这个人说过、对那个人没说过。") {
                        Button {
                            creating = true
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
            .background(AppSurface.light.background.ignoresSafeArea())
            .navigationTitle("切换身份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: onClose)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $creating) {
            PersonaEditor(profile: nil, onClose: { creating = false })
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(activeName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
            Text("现在用这个身份跟角色说话")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PhoneMetrics.Space.s)
    }

    private func row(_ profile: UserProfile) -> some View {
        let scope = profile.isDefault ? "" : profile.uid.uuidString
        let selected = scope == activeScope
        return Button {
            IdentityScope.shared.switchTo(scope)
            onClose()
        } label: {
            HStack(spacing: PhoneMetrics.Space.s) {
                ZStack {
                    Circle().fill(Theme.IconTint.indigo.opacity(0.14))
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
                                .background(Capsule().fill(Theme.IconTint.indigo.opacity(0.12)))
                        }
                    }

                    Text(profile.signature.isEmpty ? "还没写签名" : profile.signature)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: PhoneMetrics.Space.xs)

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
