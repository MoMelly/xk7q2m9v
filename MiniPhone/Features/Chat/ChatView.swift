import SwiftUI

/// 「信息」App 里的聊天界面。
///
/// 从桌面图标点进来，左上角返回桌面。顶部不设导航栏，
/// 因为真机的信息 App 没有那种页面层级感，只有一条居中的联系人标题。
struct ChatView: View {
    let settings: SettingsStore
    let onExit: () -> Void

    @State private var viewModel = ChatViewModel()
    @State private var draft = ""
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isStreaming
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                transcript
                composer
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, onExit: nil)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 17)

            VStack(alignment: .leading, spacing: 2) {
                Text("小手机")
                    .font(Theme.serif(20, weight: .semibold))
                    .foregroundStyle(Theme.cream)

                Text("直连模型 · 记录只在本机")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Theme.mint.opacity(0.7))
            }

            Spacer(minLength: 0)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 17)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - 对话区

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if let errorText = viewModel.errorText {
                        errorCard(errorText)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.isConfigured ? "它在等你说第一句" : "还差一步")
                .font(Theme.serif(20, weight: .medium))
                .foregroundStyle(Theme.cream)

            Rectangle()
                .fill(Theme.mint.opacity(0.22))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 7) {
                configRow("接口", settings.baseURL)
                configRow("模型", settings.model)
                configRow("密钥", settings.isConfigured ? "已保存" : "未填写，点右上角齿轮")
            }

            if !settings.isConfigured {
                Text("填好之后回到这里，直接打字就行。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mint.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 20)
        .padding(.top, 6)
    }

    private func configRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.mint.opacity(0.6))
                .frame(width: 32, alignment: .leading)

            Text(value)
                .font(.system(size: 12).monospaced())
                .foregroundStyle(Theme.cream.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("出错了")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.55))

            Text(text)
                .font(.system(size: 12).monospaced())
                .foregroundStyle(Theme.cream.opacity(0.9))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
    }

    // MARK: - 输入条

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("说点什么", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.cream)
                .tint(Theme.mint)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit(submit)

            Button(action: submit) {
                ZStack {
                    Circle()
                        .fill(canSend ? Theme.mint : Theme.mint.opacity(0.22))
                        .frame(width: 34, height: 34)

                    if viewModel.isStreaming {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.deepGreen)
                            .scaleEffect(0.68)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.deepGreen)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: 26)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func submit() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task {
            await viewModel.send(text, settings: settings)
        }
    }
}
