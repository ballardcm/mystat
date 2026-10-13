import AppKit

enum DashboardPlacement {
    static func frame(anchor: NSRect, visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 8
        let width: CGFloat = 424
        let top = min(anchor.minY - 5, visibleFrame.maxY - margin)
        let height = min(790, max(0, top - visibleFrame.minY - margin))
        let x = min(max(visibleFrame.minX + margin, anchor.midX - width / 2),
                    visibleFrame.maxX - width - margin)
        return NSRect(x: x, y: top - height, width: width, height: height)
    }
}
