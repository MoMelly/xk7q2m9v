import SwiftUI

/// 锁屏上的两颗小组件：左边天气，右边角色此刻的心事。
///
/// 天气是本地写死的占位，没有接天气接口，不假装有；右边读世界状态里
/// 未了结的心声，锁屏因此能看出角色现在的状态，而不是一张纯背景。
struct LockScreenWidgets: View {
    var moodLabel: String?
    var voiceText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            weather
            voice
        }
        .padding(.horizontal, 22)
    }

    private var weather: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                Text("晴 17°C")
                    .font(.system(size: 13, weight: .medium))
            }

            Text("北风 4 级")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.72))

            Text("体感温度 13°C")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 18)
    }

    private var voice: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(moodLabel ?? "安静")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))

            Text(voiceText ?? "没什么特别想说的")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 18)
    }
}

/// 锁屏底部：手电、相机，中间是模式入口。真机没有「完成」这类按钮。
struct LockScreenQuickActions: View {
    var body: some View {
        HStack {
            circle(symbol: "flashlight.off.fill")

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                Text("个人")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.12)))

            Spacer()

            circle(symbol: "camera.fill")
        }
        .padding(.horizontal, 40)
    }

    private func circle(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .glassSurface(cornerRadius: 24)
    }
}
