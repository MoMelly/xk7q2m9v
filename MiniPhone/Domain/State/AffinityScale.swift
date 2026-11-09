import Foundation

/// 好感度的档位。
///
/// 放在 `WorldStore` 外面是因为它是纯函数：提示词装配在非主线程上下里跑，
/// 挂在 `@MainActor` 的 store 上会被隔离检查拦下来，而它根本不需要那个上下文。
enum AffinityScale {
    /// 关系阶段。给界面和提示词共用，免得两边各写一套阈值。
    struct Stage {
        var label: String
        var line: String
    }

    static func stage(of value: Int) -> Stage {
        switch value {
        case ..<20:
            return Stage(label: "生疏", line: "还很客气，句子短，不会主动问私事。")
        case ..<40:
            return Stage(label: "认识", line: "能正常聊下去，偶尔会主动接一句，分寸还在。")
        case ..<60:
            return Stage(label: "熟了", line: "会开玩笑、会抱怨，话题可以往私人的方向走一点。")
        case ..<80:
            return Stage(label: "亲近", line: "说话带自己的情绪，会惦记对方说过的事，也会闹脾气。")
        default:
            return Stage(label: "很亲近", line: "不怎么客套，话可以说得没头没尾，沉默也不尴尬。")
        }
    }
}
