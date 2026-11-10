import SwiftUI

/// 文游的阅读页：一局故事的排版。
///
/// 这一页在主 App 里是唯一的例外——整页是纸，不是玻璃。
/// 主语言是液态玻璃，但文游是「摊开在读的一本书」，玻璃压在纸上会把纸压没。
/// 所以这里只在顶栏和底部输入条上留一层很薄的玻璃，正文完全落在纸面上。
///
/// 排版按书的读法来，不是按聊天气泡来：
/// 旁白首字下沉，台词包在「」里、字重加重，段落之间留出呼吸。
/// 说话人不占一整行，只在台词上方一行小字——名字一大，整页就变成聊天记录了。
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
        .background(StoryPaperBackdrop())
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
            hairline

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        openingMark(session)

                        ForEach(Array(session.lines.enumerated()), id: \.offset) { _, line in
                            storyLine(line, player: session.playerName)
                        }

                        if viewModel.isStreaming {
                            streamingLine
                        }

                        if session.isEnded, let notice = endedNotice {
                            endedBanner(notice)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
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
        HStack(alignment: .center, spacing: 10) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.StoryPaper.ink.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(session.characterNames.joined(separator: " · "))
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.6)
                    .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.85))
                    .lineLimit(1)

                Text(session.title)
                    .font(Theme.serif(17, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.StoryPaper.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if session.isEnded {
                Text(session.endingLabel.map { "结局 · \($0)" } ?? "已结束")
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: 88, alignment: .trailing)
            } else {
                Button("结束") { showEndDialog = true }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.StoryPaper.vermilion)
                    .frame(width: 44, height: 30)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial.opacity(0.55))
    }

    /// 顶栏下面那条细线。中间深、两头淡，像装订线。
    private var hairline: some View {
        LinearGradient(
            colors: [
                Theme.StoryPaper.rule.opacity(0),
                Theme.StoryPaper.rule.opacity(0.9),
                Theme.StoryPaper.rule.opacity(0.9),
                Theme.StoryPaper.rule.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    // MARK: - 正文

    /// 正文开始前那枚小印。没有它，第一段直接从顶栏下面开始，
    /// 看着像聊天记录往下滚，不像一页书。
    private func openingMark(_ session: StorySession) -> some View {
        VStack(spacing: 8) {
            Text("❖")
                .font(.system(size: 11))
                .foregroundStyle(Theme.StoryPaper.vermilion.opacity(0.55))

            Text(session.premise)
                .font(Theme.serif(12))
                .foregroundStyle(Theme.StoryPaper.inkSoft.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func storyLine(_ line: StoryLine, player: String) -> some View {
        if line.isNarration {
            narration(line.text)
        } else if line.speaker == player {
            playerLine(line.text)
        } else {
            speech(line.text, speaker: line.speaker)
        }
    }

    /// 旁白。首字下沉，其余用衬线正文。
    ///
    /// 首字是标点的时候不下沉——「“」放大到两行高只会变成一个黑洞。
    private func narration(_ text: String) -> some View {
        Group {
            if let first = text.first, !Self.leadPunctuation.contains(first) {
                (Text(String(first))
                    .font(Theme.serif(30, weight: .semibold))
                    .foregroundColor(Theme.StoryPaper.vermilion.opacity(0.9))
                    + Text(String(text.dropFirst()))
                    .font(Theme.serif(15.5))
                    .foregroundColor(Theme.StoryPaper.ink))
            } else {
                Text(text)
                    .font(Theme.serif(15.5))
                    .foregroundColor(Theme.StoryPaper.ink)
            }
        }
        .lineSpacing(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 角色说的话。名字一行小字，台词包在「」里加重。
    ///
    /// 模型有时自己就带了引号，先摘掉再包，免得出现「「……」」。
    private func speech(_ text: String, speaker: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let speaker, !speaker.isEmpty {
                Text(speaker)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.4)
                    .foregroundStyle(Theme.StoryPaper.vermilion)
            }

            Text(Self.quoted(text))
                .font(Theme.serif(16.5, weight: .medium))
                .foregroundStyle(Theme.StoryPaper.ink)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    /// 玩家自己的话。左边一道朱红细线就够，不用再标「我」。
    private func playerLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Theme.StoryPaper.vermilion.opacity(0.45))
                .frame(width: 2)
                .clipShape(Capsule())

            Text(Self.quoted(text))
                .font(Theme.serif(15.5, weight: .medium))
                .foregroundStyle(Theme.StoryPaper.ink.opacity(0.92))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
    }

    private var streamingLine: some View {
        Text(ReplyEnvelope.streamingVisible(viewModel.streamingText))
            .font(Theme.serif(15.5))
            .foregroundStyle(Theme.StoryPaper.inkSoft)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func endedBanner(_ mode: String) -> some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Theme.StoryPaper.rule.opacity(0.7))
                .frame(height: 0.6)

            Text("故事到此 · \(mode)")
                .font(Theme.serif(12))
                .kerning(1.4)
                .foregroundStyle(Theme.StoryPaper.inkSoft)

            Rectangle()
                .fill(Theme.StoryPaper.rule.opacity(0.7))
                .frame(height: 0.6)
        }
        .padding(.vertical, 14)
    }

    // MARK: - 选项与输入

    private func optionsBlock(_ session: StorySession) -> some View {
        Group {
            if !session.options.isEmpty, !viewModel.isStreaming {
                VStack(spacing: 7) {
                    ForEach(session.options, id: \.self) { option in
                        Button {
                            Task { await viewModel.turn(choiceText: option, settings: settings) }
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Text("◇")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.StoryPaper.vermilionLight)
                                    .padding(.top, 3)

                                Text(option)
                                    .font(Theme.serif(14.5))
                                    .foregroundStyle(Theme.StoryPaper.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                    .fill(Theme.StoryPaper.card.opacity(0.85))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                    .strokeBorder(Theme.StoryPaper.rule.opacity(0.75), lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Theme.StoryPaper.rule.opacity(0),
                    Theme.StoryPaper.rule.opacity(0.8),
                    Theme.StoryPaper.rule.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.8)

            HStack(spacing: 10) {
                TextField(
                    viewModel.session?.options.isEmpty == false ? "或者自己写行动" : "写下你的行动",
                    text: $draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(Theme.serif(14.5))
                .foregroundStyle(Theme.StoryPaper.ink)
                .tint(Theme.StoryPaper.vermilion)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Theme.StoryPaper.card.opacity(0.7))
                )
                .overlay {
                    Capsule().strokeBorder(Theme.StoryPaper.rule.opacity(0.6), lineWidth: 0.8)
                }

                Button {
                    let text = draft
                    draft = ""
                    Task { await viewModel.turn(choiceText: text, settings: settings) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.StoryPaper.paper)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(
                                canSend
                                    ? Theme.StoryPaper.vermilion
                                    : Theme.StoryPaper.vermilion.opacity(0.35)
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    // MARK: - 文本处理

    /// 会被放大成首字的标点。这些字下沉只会变成一个孤立的大号符号。
    private static let leadPunctuation = Set<Character>("「」『』“‘（(【[《<—-…·")

    /// 给台词套上「」。已经套过的不重复套。
    private static func quoted(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("「") && trimmed.hasSuffix("」") { return trimmed }
        if trimmed.hasPrefix("“") && trimmed.hasSuffix("”") { return trimmed }
        return "「\(trimmed)」"
    }
}

/// 纸背景。
///
/// 三层叠起来：纸色 → 四周压暗（纸摊在桌上，中间受光）→ 极淡的横纤维。
/// 纤维用固定种子生成，每次打开都一样——随机纸纹会在滚动时「动」，
/// 眼睛会一直注意到那些线。
private struct StoryPaperBackdrop: View {
    var body: some View {
        ZStack {
            Theme.StoryPaper.paper

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Theme.StoryPaper.edge.opacity(0.55)
                ]),
                center: .center,
                startRadius: 170,
                endRadius: 560
            )

            Canvas { context, size in
                for index in 0..<72 {
                    let seed = StableSeed.of("story-paper-\(index)")
                    let y = size.height * CGFloat(seed % 997) / 997
                    let inset = CGFloat(seed / 11 % 34)
                    let wobble = CGFloat(seed / 7 % 9) - 4

                    var path = Path()
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: size.width - inset + wobble, y: y))
                    context.stroke(
                        path,
                        with: .color(Theme.StoryPaper.rule.opacity(0.06)),
                        lineWidth: 0.5
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
