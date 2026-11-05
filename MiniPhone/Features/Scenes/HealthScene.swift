import SwiftUI

/// 健康。
///
/// 系统健康是「摘要 + 分类卡片」的结构：先给概览，再按类别分块。
/// 这里能拿到的只有不需要授权的设备信息和 App 自己记录的页面停留，
/// 所以开关关掉时给一张明确的说明卡，不是两行白字加大片空白。
struct HealthScene: View {
    @Bindable var settings: SettingsStore
    let world: WorldStore
    var onClose: () -> Void

    private var deviceLines: [String] {
        DeviceSnapshot.lines(allowPhoneLookups: true)
    }

    private var usage: [AppUsageRecord] {
        world.state.usage.sorted { $0.seconds > $1.seconds }
    }

    var body: some View {
        AppScreen(title: "健康", onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    overview
                    if settings.allowPhoneLookups {
                        deviceSection
                        usageSection
                    } else {
                        capabilitySection
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var overview: some View {
        GroupedSection(
            footer: settings.allowPhoneLookups
                ? "这些数据只在本机读取，通过提示词交给角色，不上传。"
                : "关闭时，电量、机型、页面停留都不会进提示词。"
        ) {
            Toggle(isOn: $settings.allowPhoneLookups) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("允许角色查手机")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                    Text("聊天时可以提到你的设备状态")
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .tint(Theme.tint)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
            .onChange(of: settings.allowPhoneLookups) { _, _ in settings.persist() }
        }
    }

    /// 关掉的时候也要有内容，否则整页只剩一行开关和一大片空白。
    /// 把「能查到什么、查不到什么」直接摊开，开关的意义才说得清。
    private var capabilitySection: some View {
        GroupedSection("开了之后能看到") {
            capabilityRow(symbol: "battery.75", title: "电量、机型、系统版本")
            RowDivider()
            capabilityRow(symbol: "clock.arrow.circlepath", title: "在这台小手机里开过哪些页面、各待多久")
            RowDivider()
            capabilityRow(symbol: "heart.slash", title: "真实健康数据：拿不到，免费签名没有这项权限")
            RowDivider()
            capabilityRow(symbol: "nosign", title: "其他 App 的屏幕使用时间：同样拿不到")
        }
    }

    private func capabilityRow(symbol: String, title: String) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondaryLabel)
                .frame(width: 22)

            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.single)
    }

    private var deviceSection: some View {
        GroupedSection("设备") {
            ForEach(Array(deviceLines.enumerated()), id: \.offset) { index, line in
                if index > 0 { RowDivider() }

                Text(line)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var usageSection: some View {
        GroupedSection("在这台小手机里", footer: "只统计你开过的页面，不含系统其他 App。") {
            if usage.isEmpty {
                Text("还没有记录")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: PhoneMetrics.Row.single)
            } else {
                ForEach(Array(usage.enumerated()), id: \.offset) { index, item in
                    if index > 0 { RowDivider() }

                    HStack {
                        Text(item.appName)
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(Theme.label)
                        Spacer(minLength: 0)
                        Text("\(Int(item.seconds / 60)) 分钟")
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)
                }
            }
        }
    }
}
