import SwiftUI

/// 世界（多存档）。
///
/// 一个世界 = 一整套东西：角色库、聊天记录、世界状态、日历、人设。
/// 换世界不是换身份——身份在「我的人设」里，记忆和角色都跟着会话走；
/// 这里换的是整台手机里的东西。
struct WorldsPage: View {
    @State private var worlds: [WorldMeta] = WorldRegistry.worlds
    @State private var activeID: String = WorldRegistry.activeID
    @State private var isCreating = false
    @State private var newName = ""
    @State private var pendingSwitch: WorldMeta?
    @State private var needsRestart = false

    var body: some View {
        AppPage(title: "世界", surface: .light) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        footer: needsRestart
                            ? "切换已经记下来了。把 App 从后台划掉再打开，才会进到新的那个世界。"
                            : "切换之后要关掉 App 再打开。聊天记录、角色、日历、人设都跟着世界走。"
                    ) {
                        ForEach(worlds) { world in
                            if world.id != worlds.first?.id {
                                RowDivider()
                            }
                            row(world)
                        }
                    }

                    GroupedSection {
                        Button {
                            newName = ""
                            isCreating = true
                        } label: {
                            GroupedRow(
                                symbol: "plus.circle.fill",
                                symbolTint: Theme.IconTint.green,
                                title: "新建一个世界",
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
        .alert("新建世界", isPresented: $isCreating) {
            TextField("给它起个名字", text: $newName)
            Button("创建") {
                WorldRegistry.create(name: newName)
                refresh()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("新世界是空的：没有角色，也没有聊天记录。")
        }
        .alert(
            "切换到「\(pendingSwitch?.name ?? "")」",
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            )
        ) {
            Button("切换") {
                if let target = pendingSwitch {
                    WorldRegistry.setActive(target.id)
                    refresh()
                    needsRestart = true
                }
                pendingSwitch = nil
            }
            Button("取消", role: .cancel) { pendingSwitch = nil }
        } message: {
            Text("当前正在用的这个世界不会被删除，随时可以切回来。切换后要重启 App。")
        }
    }

    private func row(_ world: WorldMeta) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Button {
                guard world.id != activeID else { return }
                pendingSwitch = world
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: PhoneMetrics.Space.xxs) {
                        Text(world.name)
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(AppSurface.light.label)

                        if world.id == activeID {
                            Text("正在用")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.IconTint.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Theme.IconTint.green.opacity(0.14))
                                )
                        }
                    }

                    Text(TimeFormat.shortDate(world.createdAt) + " 建的")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if world.id != WorldRegistry.defaultID, world.id != activeID {
                Button {
                    WorldRegistry.delete(world.id)
                    refresh()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
    }

    private func refresh() {
        worlds = WorldRegistry.worlds
        activeID = WorldRegistry.activeID
    }
}
