import SwiftUI

/// 桌面网格的可见范围：竖向几乎不裁，横向按状态收紧或放开。
///
/// 翻页靠横向位移，平时要裁到板子边缘，否则相邻那页会滑进屏幕。
/// 编辑态不翻页，可以左右各放宽一点：第一列图标的减号是画在格子外
/// 左上角的，裁到边缘就正好被削掉一半。
struct BoardWindow: Shape {
    /// 左右各放宽多少。减号往外偏 11pt，18 够它整个露出来。
    var horizontalInset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX - horizontalInset,
            y: rect.minY - 600,
            width: rect.width + horizontalInset * 2,
            height: rect.height + 1_200
        ))
    }
}

// MARK: - 度量

/// 一页里每一格的位置。手势命中判定和画图用同一份，懒得两边对不齐。
struct PhoneBoardMetrics {
    let size: CGSize
    let columns = PhoneMetrics.gridColumns
    let hSpacing = PhoneMetrics.gridHorizontalSpacing
    let vSpacing = PhoneMetrics.gridVerticalSpacing

    var cellWidth: CGFloat {
        (size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns)
    }

    /// 图标 + 间距 + 一行名字。名字是 11pt，行高约 13；
    /// 留 20 而不是刚好 18，是给 `minimumScaleFactor` 和那圈描边阴影一点余量——
    /// 少了这 2pt，第二行图标会压到上一行名字上。
    private static let labelAllowance: CGFloat = 20

    var cellHeight: CGFloat { PhoneMetrics.iconSize + Self.labelAllowance }

    /// 两行。上面还有三块组件，三行会顶到 Dock。
    static let rows = 2
    static var boardHeight: CGFloat {
        let cell = PhoneMetrics.iconSize + labelAllowance
        return cell * CGFloat(rows) + PhoneMetrics.gridVerticalSpacing * CGFloat(rows - 1)
    }

    func origin(at index: Int) -> CGPoint {
        let col = index % columns
        let row = index / columns
        return CGPoint(
            x: CGFloat(col) * (cellWidth + hSpacing),
            y: CGFloat(row) * (cellHeight + vSpacing)
        )
    }

    /// 格子中心（按图标本身算，不含下面那行名字）。
    /// 判断「有没有真的压在这一格上」用它。
    func center(at index: Int) -> CGPoint {
        let point = origin(at: index)
        return CGPoint(
            x: point.x + cellWidth / 2,
            y: point.y + PhoneMetrics.iconSize / 2
        )
    }

    /// 落在哪一格。
    ///
    /// 网格外面也照样给一格（取最近的列和行）：手指往组件那边或者 Dock 那边
    /// 一偏就返回 nil 的话，换位会忽然停住，感觉像拖拽只认这两行。
    func slotIndex(at point: CGPoint) -> Int? {
        guard size.width > 0, cellWidth > 0 else { return nil }
        let rawCol = Int((point.x / (cellWidth + hSpacing)).rounded(.down))
        let rawRow = Int((point.y / (cellHeight + vSpacing)).rounded(.down))
        let col = min(max(0, rawCol), columns - 1)
        let row = min(max(0, rawRow), PhoneBoardMetrics.rows - 1)
        return row * columns + col
    }
}

// MARK: - 抖动

private struct JiggleEffect: ViewModifier {
    let active: Bool
    let phase: Int

    @State private var swing = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (swing ? 1.1 : -1.1) : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                        .delay(Double(phase % 3) * 0.03)
                    : .easeOut(duration: 0.12),
                value: swing
            )
            .onChange(of: active) { _, now in
                swing = now
            }
    }
}

extension View {
    func jiggle(_ active: Bool, phase: Int) -> some View {
        modifier(JiggleEffect(active: active, phase: phase))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
