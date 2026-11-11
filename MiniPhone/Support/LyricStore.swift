import Foundation

/// 自己导进来的歌词。
///
/// 原来歌词只有一条来源：音频旁边同名的 `.lrc`。导入的歌放在 Documents/Music，
/// 用户没有地方塞那个 `.lrc`——所以「导入歌词」在 App 里其实不存在。
/// 这里把歌词单独存成文件，按曲目 id 定名，音频放哪儿都能对上。
enum LyricStore {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lyrics", isDirectory: true)
    }

    static func fileURL(for track: Track) -> URL {
        directory.appendingPathComponent(stableKey(track.id)).appendingPathExtension("lrc")
    }

    static func hasLyrics(for track: Track) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: track).path)
    }

    static func text(for track: Track) -> String? {
        try? String(contentsOf: fileURL(for: track), encoding: .utf8)
    }

    static func save(_ text: String, for track: Track) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LyricStoreError.empty }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try clean.write(to: fileURL(for: track), atomically: true, encoding: .utf8)
    }

    static func delete(for track: Track) {
        try? FileManager.default.removeItem(at: fileURL(for: track))
    }

    /// 文件选择器拿到的 URL 读成文本。lrc 有 UTF-8 也有 GB18030。
    static func read(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }

        let gb = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        if let text = String(data: data, encoding: String.Encoding(rawValue: gb)) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        throw LyricStoreError.unreadable
    }

    /// 曲目 id 里有冒号和斜杠，不能直接当文件名。
    ///
    /// 用 FNV-1a 自己算稳定值：`hashValue` 每次启动都会变，重启之后歌词就找不到了。
    /// 末尾留一段可读的原始文件名，出问题时能看出对应哪首歌。
    private static func stableKey(_ id: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        let readable = id
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .suffix(20)
        return String(hash, radix: 16) + "_" + String(readable)
    }
}

enum LyricStoreError: LocalizedError {
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .empty: return "歌词是空的。"
        case .unreadable: return "这个文件读不出来，可能不是文本，或者没给访问权限。"
        }
    }
}
