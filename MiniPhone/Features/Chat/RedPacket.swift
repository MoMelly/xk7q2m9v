import SwiftUI

/// 聊天里的红包。
///
/// 为什么不直接发「我给你发了 52 块」这句话：那在对话里只是一行字，没有物件感。
/// 做成一张卡之后，「拆」这个动作才有地方发生——它得是个能点开的东西。
///
/// 金额存的是分。文字版会跟着消息一起进提示词，所以模型看得懂发生了什么，
/// 不需要为红包另开一套状态块。
struct RedPacketBubble: View {
    let cents: Int
    let note: String
    let isOpened: Bool
    let isMine: Bool
    var onOpen: () -> Void

    private var amount: String {
        String(format: "%.2f", Double(cents) / 100)
    }

    private var cover: String {
        note.isEmpty ? (isMine ? "恭喜发财，大吉大利" : "给你留了个红包") : note
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Packet.gold)
                        .frame(width: 40, height: 40)

                    Image(systemName: isOpened ? "checkmark" : "envelope.open.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Packet.bottom)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(cover)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(isOpened ? "\(amount) 元 · 已领取" : "\(amount) 元 · 点开拆")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 232, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.Packet.top, Theme.Packet.bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Packet.gold.opacity(0.35), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpened ? "红包 \(amount) 元，已领取" : "红包 \(amount) 元，点开拆")
    }
}

/// 发红包。
///
/// 金额给几个常用的：5.20、13.14、52.0、99、131.4——这个 App 里发红包
/// 不是办事，是说话，所以不摆一个空白输入框让人自己敲。
/// 「自己填」留一档，真要发 200 也有地方。
struct RedPacketSheet: View {
    var onSend: (Int, String) -> Void
    var onCancel: () -> Void

    @State private var selected: Int? = 520
    @State private var customText = ""
    @State private var note = ""

    private let presets: [(cents: Int, label: String)] = [
        (520, "5.20"),
        (1314, "13.14"),
        (5200, "52.0"),
        (9900, "99.0"),
        (13140, "131.4")
    ]

    /// 选了「自己填」就用输入框里的数；输的不是数字就当没选。
    private var cents: Int? {
        if let selected { return selected }
        let value = Double(customText.trimmingCharacters(in: .whitespaces))
        guard let value, value > 0, value <= 20000 else { return nil }
        return Int((value * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.separator)
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("发红包")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.label)

            amountGrid

            if selected == nil {
                TextField("金额，最多 200", text: $customText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .background(Theme.rowSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))
                    .padding(.horizontal, PhoneMetrics.Space.m)
            }

            TextField("说一句（可不填）", text: $note)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.rowSurface)
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))
                .padding(.horizontal, PhoneMetrics.Space.m)

            Button {
                guard let cents else { return }
                Haptics.tap()
                onSend(cents, note.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                Text(cents == nil ? "填个金额" : "塞钱进红包")
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(cents == nil ? Theme.secondaryLabel : Theme.Packet.bottom)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(cents == nil)
            .padding(.horizontal, PhoneMetrics.Space.m)

            Button("取消", action: onCancel)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.cardSurface)
    }

    private var amountGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(presets, id: \.cents) { preset in
                amountChip(cents: preset.cents, label: preset.label)
            }
            amountChip(cents: nil, label: "自己填")
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
    }

    private func amountChip(cents: Int?, label: String) -> some View {
        let picked = selected == cents
        return Button {
            Haptics.select()
            selected = cents
        } label: {
            Text(label)
                .font(.system(size: 15, weight: picked ? .semibold : .regular))
                .foregroundStyle(picked ? Theme.Packet.bottom : Theme.label)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(picked ? Theme.Packet.gold.opacity(0.35) : Theme.rowSurface)
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
