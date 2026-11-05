import Foundation
import UIKit
import UserNotifications

/// 回复到达提醒。
///
/// 免费签名拿不到 APNs 推送权限，但**本地通知**不需要任何证书，
/// 只要用户授权就能用。所以这里只解决一件事：你在别的 App 里、
/// 它回完了，锁屏上冒一条「它回你了」。不是角色主动找你。
enum ReplyNotifier {
    private static let options: UNAuthorizationOptions = [.alert, .sound, .badge]

    /// 用户在设置里主动打开「回复提醒」时调用。启动阶段不调用：
    /// notDetermined 状态下申请权限会弹系统授权框，盖住首屏全部内容。
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: options)
        } catch {
            AppLog.ui.error("通知授权失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// App 在前台时不发——你正看着屏幕，再弹一条没意义。
    ///
    /// 授权状态在这里兜底一次：默认开启提醒但从未授权过的安装，
    /// 会在第一条回复到达时申请权限；申请成功立刻补发，避免丢首条。
    /// 已拒绝则直接跳过，系统不会重复弹框。
    @MainActor
    static func notifyReply(characterName: String, text: String) {
        deliver(title: characterName, body: String(text.prefix(120)))
    }

    /// 页面自己刷新了（购物换了一批、小红书有人发帖）。
    ///
    /// 这是本地通知，不需要推送证书。App 在前台时不发——
    /// 那时外壳会弹一条自己画的玻璃横幅，两条一起出现就重了。
    @MainActor
    static func notifyRefresh(text: String) {
        deliver(title: "小手机", body: String(text.prefix(160)))
    }

    @MainActor
    private static func deliver(title: String, body: String) {
        guard UIApplication.shared.applicationState != .active else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                post(title: title, body: body, to: center)
            case .notDetermined:
                center.requestAuthorization(options: options) { granted, error in
                    if let error {
                        AppLog.ui.error("通知授权失败: \(error.localizedDescription, privacy: .public)")
                    }
                    if granted {
                        post(title: title, body: body, to: center)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private static func post(title: String, body: String, to center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                AppLog.ui.error("通知投递失败: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
