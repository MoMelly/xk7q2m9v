import SwiftUI

/// 他的心声。
///
/// 这些是他没说出口的话：聊天里冒出来的念头、日程里压着的事。
/// 只读，不能改——改了就变成我在替他说话了。
struct CharacterVoicesSheet: View {
    let name: String
    var onClose: () -> Void

    private var all: [InnerVoiceEntry] {
        WorldStore.shared.state.person(named: name)?.voices ?? []
    }

    /// 没解开的在前。解开的留在下面，不删——他当时确实这么想过。
    private var open: [InnerVoiceEntry] {
        all.filter { !$0.isResolved }.sorted { $0.createdAt > $1.createdAt }
    }

    private var closed: [InnerVoiceEntry] {
        all.filter { $0.isResolved }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    if all.isEmpty {
                        emptyState
                    } else {
                        if !open.isEmpty { section("还没说出口", voices: open, dim: false) }
                        if !closed.isEmpty { section("已经过去的", voices: closed, dim: true) }
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(Theme.backgroundGradient)
            .navigationTitle("他的心声")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { onClose() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(_ title: String, voices: [InnerVoiceEntry], dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(voices.enumerated()), id: \.element.id) { index, voice in
                    row(voice, dim: dim)
                    if index != voices.count - 1 {
                        RowDivider(surface: .glass).padding(.leading, PhoneMetrics.Space.m)
                    }
                }
            }
            .background {
                // 液态玻璃。这一页的底永远是深绿渐变，卡片就不能用随主题翻转的
                // `rowSurface`——白天它是白卡，夜里它是深卡，深卡配深底就成了
                // 一整块墨绿色、字全糊在里面。
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                    }
            }
        }
    }

    private func row(_ voice: InnerVoiceEntry, dim: Bool) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            Image(systemName: dim ? "checkmark.circle" : "quote.opening")
                .font(.system(size: 11))
                .foregroundStyle(dim ? .white.opacity(0.4) : Theme.mint)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(voice.text)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(dim ? .white.opacity(0.55) : .white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(TimeFormat.dayLabel(voice.createdAt))
                    if voice.source == .chat {
                        Text("聊天时")
                    }
                }
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.45))

            Text("还没记下什么")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text("他有些话不会说出口。聊得多了，\n这里会攒下他没讲的那些。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
