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

    /// 锁屏时钟字号。
    static let lockClockFontSize: CGFloat = 84

    /// 锁屏上滑解锁的位移阈值。
    static let unlockDragThreshold: CGFloat = 90

    /// 打开 App 时，图标从多大开始放大。
    static let appLaunchStartScale: CGFloat = 0.86
}
