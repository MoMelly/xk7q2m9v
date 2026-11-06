import Foundation
import SwiftData

/// 一个表情。
///
/// 图片不塞进 SwiftData：几十张表情会让数据库文件涨到几十兆，
/// 备份、导出、迁移都跟着变慢。库里只存文件名，图片落在
/// `Documents/stickers/`，删记录时顺手删文件。
///
/// 内置表情不复制进 Documents：`builtInKey` 非空时直接读
/// bundle 里 `Assets/Stickers` 那张图，用户删掉记录也不会把包里的资源删掉。
@Model
final class StickerItem {
    var uid: UUID = UUID()
    /// 备注名。进提示词的就是它，所以要短、要不是符号。
    var name: String = ""
    /// 分组名。空串算「未分组」。
    var group: String = ""
    /// 内置表情的绘制键。空串表示这是上传的图片。
    var builtInKey: String = ""
    /// 上传图片在 `Documents/stickers/` 下的文件名。
    var fileName: String = ""
    var createdAt: Date = Date()

    init(
        name: String,
        group: String = "",
        builtInKey: String = "",
        fileName: String = ""
    ) {
        self.uid = UUID()
        self.name = name
        self.group = group
        self.builtInKey = builtInKey
        self.fileName = fileName
        self.createdAt = Date()
    }

    var isBuiltIn: Bool { !builtInKey.isEmpty }
}
