import SwiftUI

/// 设置。
///
/// 系统设置是「整宽分组列表 + 二级页」：主页只放入口，具体控件在子页里。
/// 之前十组控件全堆在一页、每组一张带投影的独立卡，看着像网页表单。
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    /// 行尾那行小字。UIKit 那头只有图标名，这里按调色板翻成中文。
    private var iconName: String {
        AppIconPalette.displayName(for: UIApplication.shared.alternateIconName)
    }

    private func close() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    var body: some View {
        AppScreen(title: "设置", onClose: close) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection {
                        rowLink {
                            EndpointPage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "network",
                                symbolTint: Theme.IconTint.orange,
                                title: "接口与计费",
                                value: settings.billingMode.label,
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            SamplingPage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "slider.horizontal.3",
                                symbolTint: Theme.IconTint.purple,
                                title: "生成参数",
                                value: String(format: "%.1f", settings.temperature),
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            AutoRefreshPage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "arrow.triangle.2.circlepath",
                                symbolTint: Theme.IconTint.indigo,
                                title: "自动刷新",
                                value: "每 \(settings.refreshInterval) 轮",
                                showsChevron: true
                            )
                        }
                    }

                    GroupedSection {
                        rowLink {
                            BehaviorPage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "hand.raised.fill",
                                symbolTint: Theme.IconTint.green,
                                title: "行为与隐私",
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            PersonaPage()
                        } label: {
                            GroupedRow(
                                symbol: "theatermasks.fill",
                                symbolTint: Theme.IconTint.orange,
                                title: "我的人设",
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            ThemePage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "paintpalette.fill",
                                symbolTint: Theme.IconTint.pink,
                                title: "主题",
                                value: ThemeStore.shared.accentTheme.displayName,
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            AppIconPage()
                        } label: {
                            GroupedRow(
                                symbol: "app.badge.fill",
                                symbolTint: Theme.IconTint.gray,
                                title: "App 图标",
                                value: iconName,
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            StickerPage()
                        } label: {
                            GroupedRow(
                                symbol: "face.smiling",
                                symbolTint: Theme.IconTint.orange,
                                title: "表情",
                                showsChevron: true
                            )
                        }
                    }

                    GroupedSection {
                        rowLink {
                            WorldsPage()
                        } label: {
                            GroupedRow(
                                symbol: "square.stack.3d.up.fill",
                                symbolTint: Theme.IconTint.indigo,
                                title: "世界",
                                value: WorldRegistry.active.name,
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            MemoryLibraryPage()
                        } label: {
                            GroupedRow(
                                symbol: "books.vertical.fill",
                                symbolTint: Theme.IconTint.purple,
                                title: "记忆库",
                                value: "全局设定与各角色进度",
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            DataPage()
                        } label: {
                            GroupedRow(
                                symbol: "externaldrive.fill",
                                symbolTint: Theme.IconTint.gray,
                                title: "数据与备份",
                                showsChevron: true
                            )
                        }

                        RowDivider()

                        rowLink {
                            RawReplyPage()
                        } label: {
                            GroupedRow(
                                symbol: "curlybraces",
                                symbolTint: Theme.IconTint.green,
                                title: "原始回复",
                                value: "\(RawReplyLog.shared.records.count) 条",
                                showsChevron: true
                            )
                        }
                    }

                    GroupedSection(
                        footer: "聊天内容只写在本机数据库，除了你填的接口地址，不会离开这台设备。"
                    ) {
                        GroupedRow(
                            title: "版本",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                        )
                        RowDivider()
                        GroupedRow(title: "对话存储", value: "仅本机")
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    /// 二级页入口。系统设置就是这样一行，不加额外装饰。
    private func rowLink<Destination: View, Label: View>(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) -> some View {
        NavigationLink(destination: destination, label: label)
            .buttonStyle(.plain)
    }
}
