import SwiftUI

/// 外壳的尺寸规格。
///
/// 集中在一处，避免散落到各视图里出现「这个圆角 22、那个 24」的漂移。
/// 数值按 iPhone 15/16 这一代的观感标定，不追求逐像素对齐真机。
enum PhoneMetrics {
    /// 主屏图标边长。393pt 宽的屏幕上是 60pt。
    static let iconSize: CGFloat = 60

    /// 图标圆角。iOS 用的是超椭圆，圆角半径约为边长的 22.4%。
    static let iconCornerRadius: CGFloat = 13.5

    /// 主屏网格列数。
    static let gridColumns = 4

    /// 网格横向间距。
    static let gridHorizontalSpacing: CGFloat = 22

    /// 网格纵向间距，已含图标下方的文字高度。
    static let gridVerticalSpacing: CGFloat = 16

    /// Dock 高度。图标 60 + 上下内边距。
    static let dockHeight: CGFloat = 92

    /// Dock 内部左右内边距。
    static let dockHorizontalPadding: CGFloat = 14

    /// 状态栏内容高度。真机安全区另有额外留白，这里只做内容基线。
    static let statusBarHeight: CGFloat = 44

    /// 锁屏时钟字号。真机是接近满宽的大字，84 明显偏小。
    static let lockClockFontSize: CGFloat = 110

    /// 锁屏上滑解锁的位移阈值。
    static let unlockDragThreshold: CGFloat = 90

    /// 打开 App 时，图标从多大开始放大。
    static let appLaunchStartScale: CGFloat = 0.86

    // MARK: - 系统 App 的度量

    /// 基准机逻辑画布（iPhone 15 Pro Max）。只用于对照，布局本身不按它写死。
    static let referenceSize = CGSize(width: 430, height: 932)

    /// 间距梯度。页面里不再出现裸数字。
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        /// iOS grouped 分组之间。
        static let section: CGFloat = 35
    }

    /// 圆角。分组列表 10、浮层卡片 12、小组件 22、玻璃容器 28。
    enum Radius {
        static let grouped: CGFloat = 10
        static let card: CGFloat = 12
        static let widget: CGFloat = 22
        static let glass: CGFloat = 28
        /// 列表里的封面缩略图。
        static let cover: CGFloat = 6
        /// 事件块、日期格这类小方块。
        static let block: CGFloat = 8
        /// 事件左侧的色条。
        static let bar: CGFloat = 1.5
    }

    /// 列表行高。
    enum Row {
        static let single: CGFloat = 44
        static let detailed: CGFloat = 58
    }

    /// 系统 App 的字阶。
    enum FontSize {
        static let largeTitle: CGFloat = 34
        static let navTitle: CGFloat = 17
        static let body: CGFloat = 17
        static let sub: CGFloat = 15
        static let footnote: CGFloat = 13
        static let caption: CGFloat = 12
    }
}
