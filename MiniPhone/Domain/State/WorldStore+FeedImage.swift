import Foundation

extension WorldStore {
    /// 给一条笔记挂上配图。文件名由 `FeedImageStorage` 生成。
    ///
    /// 不在这里删旧图：调用方（`FeedImageService`）先存新图再传文件名进来，
    /// 旧文件由它自己清——库里这层只认「当前这张是谁」。
    func setFeedImage(noteID: UUID, fileName: String) {
        guard let index = state.feed.firstIndex(where: { $0.id == noteID }) else { return }
        guard state.feed[index].imageFile != fileName else { return }
        state.feed[index].imageFile = fileName
        save()
    }

    /// 退回文字封面。
    func clearFeedImage(noteID: UUID) {
        guard let index = state.feed.firstIndex(where: { $0.id == noteID }),
              let old = state.feed[index].imageFile else { return }
        state.feed[index].imageFile = nil
        FeedImageStorage.delete(old)
        save()
    }

    /// 有多少条笔记已经有图。设置页告诉用户「省了多少钱」用不上，
    /// 但「已经画了几张」他看得见。
    var feedImageCount: Int {
        state.feed.filter { $0.imageFile != nil }.count
    }
}
