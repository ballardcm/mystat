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
    private static let gap: CGFloat = 8

    static func image(texts: [String]) -> NSImage {
        precondition(texts.count == labels.count)
        let width = widths.reduce(0, +) + gap * CGFloat(labels.count - 1)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
            var x: CGFloat = 0
            for index in labels.indices {
                (labels[index] as NSString).draw(at: NSPoint(x: x, y: 12), withAttributes: caption)
                let text = texts[index] as NSString
                let numberX = x + widths[index] - text.size(withAttributes: number).width
                text.draw(at: NSPoint(x: numberX, y: 0), withAttributes: number)
                x += widths[index] + gap
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
