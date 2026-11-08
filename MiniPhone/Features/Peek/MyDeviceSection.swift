import SwiftUI

/// 我这台手机。
///
/// 原来它是一个独立的「健康」App，点进去真正的功能只有一个开关：
/// 允许角色查手机。剩下两段都是这台设备能读到的信息，不是健康数据——
/// 免费签名拿不到 HealthKit，那个名字本来就名不副实。
///
/// 现在并到「TA 的手机」底部：翻完他的，顺带交代一句我这边他能看到什么。
/// 开关仍然是那个开关，存的是同一个设置项，设置 → 行为里那份也还在。
struct MyDeviceCard: View {
    @Bindable var settings: SettingsStore
    let world: WorldStore

    private var deviceLines: [String] {
        DeviceSnapshot.lines(allowPhoneLookups: true)
    }

    /// 只列前四位。这一块是给「他到底能看见多少」做个交代，
    /// 不是让我在这儿分析自己的屏幕时间。
    private var usage: [AppUsageRecord] {
        Array(world.state.usage.sorted { $0.seconds > $1.seconds }.prefix(4))
    }

    var body: some View {
        VStack(spacing: PhoneMetrics.Space.m) {
            GroupedSection(
                footer: settings.allowPhoneLookups
                    ? "这些只在本机读取，通过提示词交给他，不上传。"
                    : "关着的时候，电量、机型、页面停留都不会进提示词。"
            ) {
                Toggle(isOn: $settings.allowPhoneLookups) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("允许他查我这台手机")
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(AppSurface.light.label)

                        Text("聊天时他可以提到我的设备状态")
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }
                }
                .tint(Theme.tint)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .onChange(of: settings.allowPhoneLookups) { _, _ in settings.persist() }
            }

            if settings.allowPhoneLookups {
                deviceSection
                if !usage.isEmpty { usageSection }
            } else {
                capabilitySection
            }
        }
    }

    /// 关掉的时候也得有内容。把「能查到什么、查不到什么」摊开，
    /// 这个开关才不是一句没有后果的承诺。
    private var capabilitySection: some View {
        GroupedSection("开了之后他能看到") {
            capabilityRow(symbol: "battery.75", title: "电量、机型、系统版本")
            RowDivider()
            capabilityRow(symbol: "clock.arrow.circlepath", title: "我在这台小手机里开过哪些页面、各待多久")
            RowDivider()
            capabilityRow(symbol: "heart.slash", title: "真实健康数据：拿不到，免费签名没这项权限")
            RowDivider()
            capabilityRow(symbol: "nosign", title: "别的 App 的屏幕使用时间：同样拿不到")
        }
    }

    private var deviceSection: some View {
        GroupedSection("我这边的设备") {
            ForEach(Array(deviceLines.enumerated()), id: \.offset) { index, line in
                if index > 0 { RowDivider() }

                Text(line)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var usageSection: some View {
        GroupedSection("我在这台小手机里", footer: "只统计我开过的页面，不含系统其他 App。") {
            ForEach(Array(usage.enumerated()), id: \.offset) { index, item in
                if index > 0 { RowDivider() }

                HStack {
                    Text(item.appName)
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .foregroundStyle(AppSurface.light.label)

                    Spacer(minLength: 0)

                    Text("\(Int(item.seconds / 60)) 分钟")
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    private func capabilityRow(symbol: String, title: String) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .frame(width: 22)

            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.single)
    }
}
