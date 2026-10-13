import AppKit

@MainActor
enum MenuBarMeter {
    private static let labels = ["CPU", "MEM", "GPU"]
    private static let caption: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: NSColor.black
    ]
    private static let number: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.black
    ]
    // Reserve the entire display range, including paused and unavailable states.
    // Measuring the current reading makes every item to our left shift at digit boundaries.
    private static let numberWidth = ["100%", "Ⅱ", "—"].map {
        ($0 as NSString).size(withAttributes: number).width
    }.max()!
    private static let widths = labels.map {
        ceil(max(($0 as NSString).size(withAttributes: caption).width, numberWidth))
    }
    // Keep the groups compact without shrinking the reserved three-digit cells.
    private static let gap: CGFloat = 4

    static func image(texts: [String]) -> NSImage {
        precondition(texts.count == labels.count)
        let width = widths.reduce(0, +) + gap * CGFloat(labels.count - 1)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
            var x: CGFloat = 0
            for index in labels.indices {
                let label = labels[index] as NSString
                let captionWidth = label.size(withAttributes: caption).width
                let captionX = x + widths[index] - captionWidth
                label.draw(at: NSPoint(x: captionX, y: 12), withAttributes: caption)
                let text = texts[index] as NSString
                let remaining = widths[index] - text.size(withAttributes: number).width
                // Numeric readings keep their percent signs aligned. Standalone state
                // symbols stay under the fixed caption center, even though the cell
                // also reserves the extra digit that is rarely needed for 100%.
                let numberX = texts[index] == "Ⅱ" || texts[index] == "—"
                    ? captionX + (captionWidth - text.size(withAttributes: number).width) / 2
                    : x + remaining
                text.draw(at: NSPoint(x: numberX, y: 0), withAttributes: number)
                x += widths[index] + gap
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
