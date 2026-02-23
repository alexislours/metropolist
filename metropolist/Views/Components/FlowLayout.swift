import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var rows: [[Int]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowHeights: [CGFloat] = []

        // First pass: assign items to rows
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                rowHeights.append(rowHeight)
                rows.append([])
                rowWidths.append(0)
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rows[rows.count - 1].append(index)
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            rowWidths[rowWidths.count - 1] = currentX - spacing
        }
        rowHeights.append(rowHeight)

        // Second pass: apply horizontal alignment
        if alignment == .center {
            for (rowIndex, row) in rows.enumerated() {
                let rowWidth = rowWidths[rowIndex]
                let offset = max(0, (maxWidth - rowWidth) / 2)
                for index in row {
                    positions[index].x += offset
                }
            }
        }

        let totalHeight = rowHeights.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }
}
