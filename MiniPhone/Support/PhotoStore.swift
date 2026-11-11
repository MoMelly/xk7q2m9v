import Foundation
import UIKit

/// 相册里的一张本机照片。
struct PhotoFile: Identifiable, Hashable {
    let name: String
    let date: Date

    var id: String { name }
}

/// 本机照片。
///
/// 「照片」原来只收聊天里发过的模拟图：自己一张都放不进来，打开就是
/// 「还没有照片」，所以看不出这个 App 是干嘛的。这里管 Documents/Photos
/// 里的真实文件，导入、查看、删除都走它。
enum PhotoStore {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
    }

    static func all() -> [PhotoFile] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return files
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .compactMap { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date.distantPast
                return PhotoFile(name: url.lastPathComponent, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: name).path)
    }

    /// 存成 JPEG。名称用时间戳，同一秒里连拍也不会互相覆盖。
    @discardableResult
    static func save(_ data: Data) throws -> PhotoFile {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let image = UIImage(data: data)
        let jpeg = image?.jpegData(compressionQuality: 0.86) ?? data
        let name = "photo-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try jpeg.write(to: url(for: name), options: .atomic)

        return PhotoFile(name: name, date: Date())
    }

    static func delete(_ name: String) throws {
        try FileManager.default.removeItem(at: url(for: name))
    }
}
