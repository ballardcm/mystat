import AppKit

@MainActor
enum MenuBarMeter {
    @MainActor
    final class Cache {
        private var texts: [String]?
        private var currentImage: NSImage?

        func image(texts: [String]) -> NSImage {
            if self.texts == texts, let currentImage { return currentImage }
            let image = MenuBarMeter.image(texts: texts)
            self.texts = texts
            currentImage = image
            return image
        }
    }

    private static let labels = ["CPU", "MEM", "GPU"]
    private static let caption: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: NSColor.black
    ]
    // Optimize the usual two-digit reading. Keep a fixed column and center anchor
    // across digit changes so neither this item nor its neighbors can shift.
    private static let columnWidth: CGFloat = 27
    private static let gap: CGFloat = 4

    private static func numberAttributes(for text: String) -> [NSAttributedString.Key: Any] {
        let digits = text.filter(\.isNumber).count
        let size: CGFloat = digits == 1 ? 12 : digits == 3 ? 9 : 11
        return [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium),
                .foregroundColor: NSColor.black]
    }

    static func image(texts: [String]) -> NSImage {
        precondition(texts.count == labels.count)
        let width = columnWidth * CGFloat(labels.count) + gap * CGFloat(labels.count - 1)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
            for index in labels.indices {
                let x = CGFloat(index) * (columnWidth + gap)
                let label = labels[index] as NSString
                label.draw(at: NSPoint(x: x + (columnWidth - label.size(withAttributes: caption).width) / 2, y: 12),
                           withAttributes: caption)
                let text = texts[index] as NSString
                let number = numberAttributes(for: texts[index])
                let size = (number[.font] as! NSFont).pointSize
                text.draw(at: NSPoint(x: x + (columnWidth - text.size(withAttributes: number).width) / 2,
                                      y: (11 - size) / 2), withAttributes: number)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
