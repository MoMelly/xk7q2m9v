import SwiftUI
import UIKit

/// 系统分享面板。
///
/// 导出备份要靠它把文件送进「文件」App——自签应用没有 iCloud 容器，
/// 用户能拿到的唯一持久位置就是本机的文件目录。
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
