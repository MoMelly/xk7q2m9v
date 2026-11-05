import Foundation
import UIKit

/// 角色能查到的真机数据。
///
/// 只列不需要授权就能读的项。HealthKit 与 Screen Time 在免费签名的
/// provisioning profile 下拿不到 entitlement，见 ROADMAP §6 编号 15。
enum DeviceSnapshot {
    static func lines(allowPhoneLookups: Bool) -> [String] {
        guard allowPhoneLookups else { return [] }

        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        var lines: [String] = []

        let level = device.batteryLevel
        if level >= 0 {
            let stateText: String
            switch device.batteryState {
            case .charging: stateText = "，充电中"
            case .full: stateText = "，已充满"
            case .unplugged: stateText = ""
            default: stateText = ""
            }
            lines.append("电池 \(Int(level * 100))%\(stateText)")
        }

        lines.append("系统 \(device.systemName) \(device.systemVersion)")
        lines.append("机型 \(device.model)")
        lines.append("时区 \(TimeZone.current.identifier)")

        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attributes[.systemFreeSize] as? NSNumber {
            let text = ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)
            lines.append("可用空间 \(text)")
        }

        return lines
    }
}
