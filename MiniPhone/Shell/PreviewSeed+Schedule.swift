import Foundation

extension PreviewSeeder {
    /// 日程半屏卡的截图底子。
    ///
    /// 要拍到「有地点、有同去」的样子；空条目只会拍出那句灰字提示，
    /// 改版后的三行详情就白截了。
    func seedScheduleCard() {
        guard world.state.schedule?.items.isEmpty ?? true else { return }
        world.upsertScheduleItem(
            ScheduleItem(
                hour: 14,
                title: "去取修好的鞋",
                mood: .calm,
                note: "顺便买点猫粮",
                place: "巷口那家店",
                companions: ["小满"]
            )
        )
        world.upsertScheduleItem(
            ScheduleItem(hour: 19, title: "跟她吃个饭", mood: .glad, place: "老地方")
        )
    }
}
