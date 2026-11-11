import SwiftUI

/// 阅读页的纸色。
///
/// 夜里用纸白会把整页照成一块灯板，所以夜间是深纸配灰白字，不是白底调暗。
enum ReaderPaper: String, CaseIterable, Identifiable {
    case cream
    case paper
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cream: return "米黄"
        case .paper: return "纸白"
        case .night: return "夜间"
        }
    }

    var background: Color {
        switch self {
        case .cream: return Theme.ReadPaper.cream
        case .paper: return Theme.ReadPaper.paper
        case .night: return Theme.ReadPaper.night
        }
    }

    var ink: Color {
        switch self {
        case .cream: return Theme.ReadPaper.creamInk
        case .paper: return Theme.ReadPaper.paperInk
        case .night: return Theme.ReadPaper.nightInk
        }
    }

    /// 设置面板里的预览块要不要描边。深色纸不描就看不出边界。
    var needsBorder: Bool { self == .night }
}

/// 排版设置：字号、行距、纸色。
///
/// 原来只有一个字号菜单，藏在右上角的 `textformat.size` 里，
/// 行距和底色根本没得调——这就是「阅读完全没有设置」。
struct ReaderSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var lineSpacing: Double
    @Binding var paperRaw: String
    @Binding var margin: Double

    @Environment(\.dismiss) private var dismiss

    private let fontChoices: [Double] = [16, 18, 20, 22, 24]
    private let spacingChoices: [Double] = [6, 9, 13]
    /// 左右留白。窄一点一页多几个字，宽一点更像纸书。
    private let marginChoices: [Double] = [16, 22, 32]

    private var paper: ReaderPaper {
        ReaderPaper(rawValue: paperRaw) ?? .cream
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.m) {
                    GroupedSection("字号") {
                        HStack(spacing: 8) {
                            ForEach(fontChoices, id: \.self) { size in
                                choice("\(Int(size))", active: Int(fontSize) == Int(size)) {
                                    fontSize = size
                                }
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.s)
                    }

                    GroupedSection("行距") {
                        HStack(spacing: 8) {
                            ForEach(spacingChoices, id: \.self) { spacing in
                                choice(spacingTitle(spacing), active: Int(lineSpacing) == Int(spacing)) {
                                    lineSpacing = spacing
                                }
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.s)
                    }

                    GroupedSection("页边距", footer: "改完这一页会重新排一遍，页码可能跟着变。") {
                        HStack(spacing: 8) {
                            ForEach(marginChoices, id: \.self) { value in
                                choice(marginTitle(value), active: Int(margin) == Int(value)) {
                                    margin = value
                                }
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.s)
                    }

                    GroupedSection("底色", footer: "选完直接生效，不用退出重进。") {
                        HStack(spacing: 10) {
                            ForEach(ReaderPaper.allCases) { item in
                                Button {
                                    paperRaw = item.rawValue
                                } label: {
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(item.background)
                                            .frame(height: 54)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(
                                                        paper == item ? Theme.tint : (item.needsBorder ? Color.white.opacity(0.18) : Color.black.opacity(0.08)),
                                                        lineWidth: paper == item ? 2 : 1
                                                    )
                                            }
                                            .overlay {
                                                Text("字")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(item.ink)
                                            }

                                        Text(item.title)
                                            .font(.system(size: PhoneMetrics.FontSize.caption))
                                            .foregroundStyle(paper == item ? Theme.tint : AppSurface.light.secondaryLabel)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.s)
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(AppSurface.light.background)
            .navigationTitle("排版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.medium])
    }

    private func choice(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.body, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? .white : AppSurface.light.label)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? Theme.tint : AppSurface.light.rowSurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func spacingTitle(_ value: Double) -> String {
        switch value {
        case 6: return "紧"
        case 13: return "松"
        default: return "中"
        }
    }

    private func marginTitle(_ value: Double) -> String {
        switch value {
        case 16: return "窄"
        case 32: return "宽"
        default: return "中"
        }
    }
}
