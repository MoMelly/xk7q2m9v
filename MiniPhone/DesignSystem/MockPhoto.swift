import SwiftUI

/// 私聊里发的那种「图」。
///
/// 不读图片文件，也不接相册：八种场景按 seed 现画，同一个 seed 每次画得一样。
/// 好处是包体不涨、不牵扯版权，也不会在相册里留下别人的照片；
/// 画的全是风景和静物，没有一张人像。
enum MockPhotoSubject: Int, CaseIterable {
    case dusk
    case rain
    case night
    case coffee
    case cat
    case sea
    case cloud
    case lamp

    static func of(_ seed: Int) -> MockPhotoSubject {
        MockPhotoSubject(rawValue: StableSeed.index(seed, count: MockPhotoSubject.allCases.count)) ?? .dusk
    }

    /// 直接指定这张图时用的种子。加一圈总数避开 0——它是「没有图」的哨兵值。
    /// 预览和真正发出去都取这个数，才不会点「猫」发出海。
    var seed: Int { rawValue + MockPhotoSubject.allCases.count }

    /// 从一句说明里认出是哪张图：写「窗外的雨」就给雨窗。
    /// 认不出来返回 nil，交给调用方按哈希随便落一张。
    static func matching(_ note: String) -> MockPhotoSubject? {
        allCases.first { note.contains($0.title) }
    }

    var title: String {
        switch self {
        case .dusk: return "黄昏"
        case .rain: return "雨窗"
        case .night: return "夜空"
        case .coffee: return "咖啡"
        case .cat: return "猫"
        case .sea: return "海"
        case .cloud: return "云"
        case .lamp: return "灯串"
        }
    }
}

/// 一张模拟照片。
///
/// 尺寸完全跟着父容器走：气泡里是 4:3 的大图，发图面板里是 4:3 的缩略格，
/// 同一份代码两种场合都能用，不用维护两套画法。
struct MockPhoto: View {
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            canvas(proxy.size)
        }
        .clipped()
    }

    @ViewBuilder
    private func canvas(_ size: CGSize) -> some View {
        switch MockPhotoSubject.of(seed) {
        case .dusk: dusk(size)
        case .rain: rain(size)
        case .night: night(size)
        case .coffee: coffee(size)
        case .cat: cat(size)
        case .sea: sea(size)
        case .cloud: cloud(size)
        case .lamp: lamp(size)
        }
    }

    // MARK: - 黄昏

    private func dusk(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.duskSkyTop,
                         Theme.PhotoSurface.duskSkyMid,
                         Theme.PhotoSurface.duskSkyLow],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Theme.PhotoSurface.duskSun)
                .frame(width: size.width * 0.24, height: size.width * 0.24)
                .blur(radius: size.width * 0.035)
                .position(x: size.width * 0.72, y: size.height * 0.36)

            ridge(size, base: 0.68, peak: 0.55, spread: 0.52)
                .fill(Theme.PhotoSurface.duskHillFar)

            ridge(size, base: 0.82, peak: 0.70, spread: 0.38)
                .fill(Theme.PhotoSurface.duskHillNear)
        }
    }

    /// 一道山脊：左边起、中间挑高、右边落回同一水平。
    private func ridge(_ size: CGSize, base: CGFloat, peak: CGFloat, spread: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * base))
            path.addQuadCurve(
                to: CGPoint(x: size.width * spread, y: size.height * peak),
                control: CGPoint(x: size.width * spread * 0.45, y: size.height * (peak - 0.04))
            )
            path.addQuadCurve(
                to: CGPoint(x: size.width, y: size.height * base),
                control: CGPoint(x: size.width * (spread + 0.24), y: size.height * (peak - 0.02))
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }

    // MARK: - 雨窗

    private func rain(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.rainTop, Theme.PhotoSurface.rainBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Theme.PhotoSurface.rainDrop.opacity(0.16))
                .frame(width: size.width * 0.34, height: size.width * 0.34)
                .blur(radius: size.width * 0.09)
                .position(x: size.width * 0.30, y: size.height * 0.28)

            Path { path in
                var x = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height * 0.30, y: size.height))
                    x += size.width * 0.12
                }
            }
            .stroke(Theme.PhotoSurface.rainDrop.opacity(0.26), lineWidth: max(1, size.width * 0.007))

            Rectangle()
                .fill(Theme.PhotoSurface.rainSill)
                .frame(height: size.height * 0.14)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - 夜空

    private func night(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.nightTop, Theme.PhotoSurface.nightBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // 星点位置由 seed 决定，不抖动：同一条消息每次打开都是同一片天。
            ForEach(0..<18, id: \.self) { index in
                let x = CGFloat(StableSeed.index(seed &+ index * 37, count: 100)) / 100
                let y = CGFloat(StableSeed.index(seed &+ index * 61, count: 62)) / 100

                Circle()
                    .fill(Color.white.opacity(0.35 + Double(StableSeed.index(index &+ seed, count: 5)) / 12))
                    .frame(width: max(1.4, size.width * 0.008))
                    .position(x: size.width * x, y: size.height * y)
            }

            Image(systemName: "moon.fill")
                .font(.system(size: size.width * 0.17))
                .foregroundStyle(Theme.PhotoSurface.nightMoon)
                .shadow(color: Theme.PhotoSurface.nightMoon.opacity(0.35), radius: size.width * 0.04)
                .position(x: size.width * 0.76, y: size.height * 0.26)
        }
    }

    // MARK: - 咖啡

    private func coffee(_ size: CGSize) -> some View {
        let cup = size.width * 0.46

        return ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.coffeeTable, Theme.PhotoSurface.coffeeTableEdge],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 木纹，压得很淡，只当纹理用。
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Theme.PhotoSurface.coffeeTableEdge.opacity(0.35))
                    .frame(height: 1)
                    .offset(y: size.height * (0.18 + CGFloat(index) * 0.21))
            }

            Circle()
                .fill(Theme.PhotoSurface.coffeeCup.opacity(0.5))
                .frame(width: cup * 1.28, height: cup * 1.28)

            // 把手：只画右半边，靠遮罩切掉左半。
            Circle()
                .strokeBorder(Theme.PhotoSurface.coffeeCup, lineWidth: size.width * 0.038)
                .frame(width: cup * 0.42, height: cup * 0.42)
                .offset(x: cup * 0.52)
                .mask(alignment: .trailing) {
                    Rectangle().frame(width: cup * 0.22)
                }

            Circle()
                .fill(Theme.PhotoSurface.coffeeCup)
                .frame(width: cup, height: cup)

            Circle()
                .fill(Theme.PhotoSurface.coffeeLiquid)
                .frame(width: cup * 0.78, height: cup * 0.78)

            Circle()
                .fill(Theme.PhotoSurface.coffeeCrema.opacity(0.65))
                .frame(width: cup * 0.30, height: cup * 0.30)
                .offset(x: -cup * 0.10, y: -cup * 0.08)
                .blur(radius: size.width * 0.012)
        }
    }

    // MARK: - 猫

    private func cat(_ size: CGSize) -> some View {
        let head = size.width * 0.24
        let centerX = size.width * 0.5

        return ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.catWall, Theme.PhotoSurface.catFloor],
                startPoint: .top,
                endPoint: .bottom
            )

            // 尾巴：一条从身后绕到前面的曲线。
            Path { path in
                path.move(to: CGPoint(x: centerX + size.width * 0.16, y: size.height * 0.78))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + size.width * 0.30, y: size.height * 0.62),
                    control: CGPoint(x: centerX + size.width * 0.34, y: size.height * 0.82)
                )
            }
            .stroke(Theme.PhotoSurface.catBody, style: StrokeStyle(lineWidth: size.width * 0.035, lineCap: .round))

            Ellipse()
                .fill(Theme.PhotoSurface.catBody)
                .frame(width: size.width * 0.30, height: size.height * 0.40)
                .position(x: centerX, y: size.height * 0.70)

            // 耳朵先画，头和身体压在上面才不出接缝。
            ForEach([-1.0, 1.0], id: \.self) { side in
                Path { path in
                    let baseX = centerX + CGFloat(side) * head * 0.26
                    path.move(to: CGPoint(x: baseX - head * 0.10, y: size.height * 0.40))
                    path.addLine(to: CGPoint(x: baseX - head * 0.03, y: size.height * 0.30))
                    path.addLine(to: CGPoint(x: baseX + head * 0.14, y: size.height * 0.38))
                    path.closeSubpath()
                }
                .fill(Theme.PhotoSurface.catBody)
            }

            Circle()
                .fill(Theme.PhotoSurface.catBody)
                .frame(width: head, height: head)
                .position(x: centerX, y: size.height * 0.44)
        }
    }

    // MARK: - 海

    private func sea(_ size: CGSize) -> some View {
        let horizon = size.height * 0.56

        return ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.seaSkyTop, Theme.PhotoSurface.seaSkyLow],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Color.clear.frame(height: horizon)
                LinearGradient(
                    colors: [Theme.PhotoSurface.seaWater, Theme.PhotoSurface.seaWaterDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            Circle()
                .fill(Color.white.opacity(0.78))
                .frame(width: size.width * 0.11, height: size.width * 0.11)
                .position(x: size.width * 0.34, y: horizon - size.width * 0.16)

            // 太阳在水面拉出的那条竖光带。
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: size.width * 0.05, height: size.height * 0.42)
                .position(x: size.width * 0.34, y: horizon + size.height * 0.22)
                .blur(radius: size.width * 0.02)

            ForEach(0..<5, id: \.self) { index in
                let inset = size.width * (0.06 + CGFloat(index) * 0.03)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: size.width - inset * 2, height: max(1, size.height * 0.004))
                    .position(
                        x: size.width * 0.5,
                        y: horizon + size.height * (0.10 + CGFloat(index) * 0.09)
                    )
            }
        }
    }

    // MARK: - 云

    private func cloud(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.cloudSkyTop, Theme.PhotoSurface.cloudSkyLow],
                startPoint: .top,
                endPoint: .bottom
            )

            puff(size, at: CGPoint(x: 0.26, y: 0.62), scale: 1.0)
            puff(size, at: CGPoint(x: 0.72, y: 0.38), scale: 0.78)
            puff(size, at: CGPoint(x: 0.64, y: 0.82), scale: 0.55)
        }
    }

    /// 一朵云：四个圆叠在一起，再糊一下边缘，就不像三个球。
    private func puff(_ size: CGSize, at point: CGPoint, scale: CGFloat) -> some View {
        let unit = size.width * 0.17 * scale

        return ZStack {
            Circle().frame(width: unit * 1.20).offset(x: -unit * 0.52, y: unit * 0.10)
            Circle().frame(width: unit * 1.55).offset(x: 0, y: -unit * 0.12)
            Circle().frame(width: unit * 1.10).offset(x: unit * 0.62, y: unit * 0.14)
            Circle().frame(width: unit * 1.35).offset(x: unit * 0.16, y: unit * 0.06)
        }
        .foregroundStyle(Theme.PhotoSurface.cloudPuff.opacity(0.92))
        .blur(radius: unit * 0.10)
        .position(x: size.width * point.x, y: size.height * point.y)
    }

    // MARK: - 灯串

    private func lamp(_ size: CGSize) -> some View {
        let count = 9
        let sag = size.height * 0.16

        return ZStack {
            LinearGradient(
                colors: [Theme.PhotoSurface.lampNightTop, Theme.PhotoSurface.lampNightBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.22))
                path.addQuadCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.22),
                    control: CGPoint(x: size.width * 0.5, y: size.height * 0.22 + sag * 2)
                )
            }
            .stroke(Color.white.opacity(0.16), lineWidth: max(0.8, size.width * 0.004))

            ForEach(0..<count, id: \.self) { index in
                let ratio = CGFloat(index) / CGFloat(count - 1)
                // 抛物线上取点：两端高、中间低，跟上面那条曲线重合。
                let y = size.height * 0.22 + sag * 4 * ratio * (1 - ratio)
                let x = size.width * ratio

                ZStack {
                    Circle()
                        .fill(Theme.PhotoSurface.lampGlow.opacity(0.30))
                        .frame(width: size.width * 0.10, height: size.width * 0.10)
                        .blur(radius: size.width * 0.03)

                    Circle()
                        .fill(Theme.PhotoSurface.lampGlow)
                        .frame(width: size.width * 0.028, height: size.width * 0.028)
                }
                .position(x: x, y: y + size.height * 0.03)
            }
        }
    }
}
