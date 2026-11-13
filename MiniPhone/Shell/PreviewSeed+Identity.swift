import SwiftUI

/// 截图流水线里的身份切换。
///
/// 单独拆出来：`PreviewSeed.swift` 已经贴着 600 行上限，而这两个状态
/// 要验的是「换了人之后，好感度、火花、记忆是不是真的从头开始」。
@MainActor
extension PreviewSeeder {

    /// 每个截图状态都从默认身份起跑。
    ///
    /// CI 所有状态共用同一台模拟器，UserDefaults 会留着上一个状态设的身份。
    /// 不重置的话，后面那些种子会全写进另一个身份的文件里，截图张冠李戴。
    func startFromDefaultIdentity() {
        guard !IdentityScope.shared.isDefault else { return }
        // 先把当前身份那份落盘，再换文件；直接 reload 会把内存里
        // 还没写出去的改动丢掉，也会让两个身份的状态互相盖。
        world.save()
        IdentityScope.shared.resetToDefault()
        world.adoptActiveIdentityFile()
        world.reload()
    }

    /// 垫完默认身份的数据之后再切过去。
    ///
    /// 老身份那份留在盘上不动，新身份没有自己的文件，读出来就是一份全新
    /// 的空状态：好感度回到初始值、火花清零、事实和心事一条都没有。
    func switchToSecondIdentity() {
        IdentityScope.shared.switchTo("preview-second-persona")
        world.reloadForActiveIdentity()
    }
}
