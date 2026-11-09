import SwiftUI

/// 文游的阅读页：一局故事的纯文字排版。
///
/// 不是聊天气泡——小说式排版：旁白衬线斜体、台词带说话人名、玩家的话单独着色。
/// 底部是选项行与自由输入框；结束后变成只读。
struct StoryReadPage: View {
    let settings: SettingsStore
    @Bindable var viewModel: StoryGameViewModel
    var onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft = ""
    @State private var showEndDialog = false
    @State private var endedNotice: String?

    private var session: StorySession? { viewModel.session }

    var body: some View {
        Group {
            if let session {
                content(session)
            }
        }
        .background(Theme.settingsBackground)
        .confirmationDialog("这段剧情怎么记？", isPresented: $showEndDialog, titleVisibility: .visible) {
            ForEach(StoryMemoryMode.allCases) { mode in
                Button(mode.blurb) {
                    viewModel.end(mode: mode, context: modelContext)
                    endedNotice = mode.displayName
                }
            }
            Button("先不结束", role: .cancel) {}
        }
    }

    private func content(_ session: StorySession) -> some View {
        VStack(spacing: 0) {
            header(session)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                        ForEach(Array(session.lines.enumerated()), id: \.offset) { _, line in
                            storyLine(line, player: session.playerName)
                        }

                        if viewModel.isStreaming {
                            Text(ReplyEnvelope.streamingVisible(viewModel.streamingText))
                                .font(Theme.serif(PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.secondaryInk)
                                .italic()
                        }

                        if session.isEnded, let notice = endedNotice {
                            endedBanner(notice)
                        }

                        Color.clear
                            .frame(height: 8)
                            .id("bottom")
                    }
                    .padding(.horizontal, PhoneMetrics.Space.l)
                    .padding(.vertical, PhoneMetrics.Space.m)
                }
                .onChange(of: session.lines.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if !session.isEnded {
                optionsBlock(session)
                inputBar
            }
        }
    }

    // MARK: - 顶栏

    private func header(_ session: StorySession) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurface.light.label)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: PhoneMetrics.FontSize.navTitle, weight: .semibold))
                    .foregroundStyle(AppSurface.light.label)
                Text(session.characterNames.joined(separator: "、"))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Spacer(minLength: 0)

            if session.isEnded {
                Text(session.endingLabel.map { "结局 · \($0)" } ?? "已结束")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: session.endingLabel == nil ? .regular : .medium))
                    .foregroundStyle(session.endingLabel == nil ? AppSurface.light.secondaryLabel : Theme.brand)
            } else {
                Button("结束") {
                    showEndDialog = true
                }
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                .foregroundStyle(Theme.brand)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    // MARK: - 正文排版

    @ViewBuilder
    private func storyLine(_ line: StoryLine, player: String) -> some View {
        if line.isNarration {
            Text(line.text)
                .font(Theme.serif(PhoneMetrics.FontSize.body))
                .foregroundStyle(Theme.secondaryInk)
                .italic()
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.speaker == player {
            VStack(alignment: .leading, spacing: 3) {
                Text(player)
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .semibold))
                    .foregroundStyle(Theme.tint)
                Text(line.text)
                    .font(Theme.serif(PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.speaker ?? "")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                Text(line.text)
                    .font(Theme.serif(PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func endedBanner(_ mode: String) -> some View {
        Text("故事结束 · \(mode)")
            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(PhoneMetrics.Space.m)
    }

    // MARK: - 选项与输入

    private func optionsBlock(_ session: StorySession) -> some View {
        Group {
            if !session.options.isEmpty, !viewModel.isStreaming {
                VStack(spacing: PhoneMetrics.Space.xs) {
                    ForEach(session.options, id: \.self) { option in
                        Button {
                            Task { await viewModel.turn(choiceText: option, settings: settings) }
                        } label: {
                            Text(option)
                                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                                .foregroundStyle(AppSurface.light.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, PhoneMetrics.Space.m)
                                .padding(.vertical, PhoneMetrics.Space.s)
                                .background(
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                                        .fill(AppSurface.light.rowSurface)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                                        .strokeBorder(Theme.separator, lineWidth: 1)
                                }
                            }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.bottom, PhoneMetrics.Space.xs)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            TextField(viewModel.session?.options.isEmpty == false ? "或者自己写行动" : "写下你的行动", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .lineLimit(1...3)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)
                .background(
                    Capsule().fill(AppSurface.light.rowSurface)
                )

            Button {
                let text = draft
                draft = ""
                Task { await viewModel.turn(choiceText: text, settings: settings) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.deepGreen)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.mint))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
    }
}
