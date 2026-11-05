import Foundation

/// 稳定种子。
///
/// `String.hashValue` 每个进程都会重新随机，用它当配色种子的话，
/// 同一条笔记重启一次就换个颜色。这里自己算一个跨进程不变的哈希。
enum StableSeed {
    static func of(_ text: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Int(hash % 100_000)
    }

    /// 取余，负数也能落到 0..<count。
    static func index(_ seed: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs(seed) % count
    }
}
