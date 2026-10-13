import AppKit

@main
struct MenuBarMeterTests {
    @MainActor
    static func main() throws {
        let states = ["0%", "9%", "14%", "99%", "100%", "Ⅱ", "—"]
        let reference = MenuBarMeter.image(texts: ["100%", "100%", "100%"])
        // Vary all columns independently, including startup/missing and pause states.
        for cpu in states {
            for memory in states {
                for gpu in states {
                    let image = MenuBarMeter.image(texts: [cpu, memory, gpu])
                    precondition(image.size == reference.size, "Meter size changed for \(cpu), \(memory), \(gpu)")
                    precondition(image.isTemplate, "Meter must adapt to menu-bar appearance")
                }
            }
        }
        // Compare the rendered percent-sign pixels, not just the text layout arithmetic.
        // A left-aligned implementation has the same image size but fails this check.
        for scale in [1, 2] {
            let baseline = bitmap(reference, scale: scale)
            for column in 0..<3 {
                assertCentered(baseline, column: column, rows: 0..<10 * scale, scale: scale, label: "Caption")
                for symbol in ["Ⅱ", "—"] {
                    let rendered = bitmap(MenuBarMeter.image(texts: [symbol, symbol, symbol]), scale: scale)
                    assertCentered(rendered, column: column, rows: 10 * scale..<22 * scale, scale: scale, label: symbol)
                }
            }
            for value in ["0%", "9%", "14%", "99%"] {
                let rendered = bitmap(MenuBarMeter.image(texts: [value, value, value]), scale: scale)
                for column in 0..<3 {
                    // The last five points of each number contain its percent sign.
                    let right = Int((reference.size.width - 16) / 3) * (column + 1) + 8 * column
                    for x in ((right - 5) * scale)..<(right * scale) {
                        for y in 10 * scale..<22 * scale {
                            precondition(rendered.colorAt(x: x, y: y) == baseline.colorAt(x: x, y: y),
                                         "Percent sign moved at \(value), column \(column), scale \(scale)")
                        }
                    }
                }
            }
        }
        if CommandLine.arguments.contains("--live") {
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let neighbor = NSStatusBar.system.statusItem(withLength: 20)
            neighbor.button?.title = "·"
            defer {
                NSStatusBar.system.removeStatusItem(item)
                NSStatusBar.system.removeStatusItem(neighbor)
            }
            item.button?.image = reference
            // Let the menu-bar server finish inserting both temporary items first.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
            var expectedWidth: CGFloat?
            var expectedNeighbor: NSRect?
            for value in states + states.reversed() {
                item.button?.image = MenuBarMeter.image(texts: [value, value, value])
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
                guard let button = item.button, let window = button.window,
                      let neighborWindow = neighbor.button?.window else {
                    fatalError("Live status items unavailable")
                }
                let width = window.frame.width
                if let expectedWidth { precondition(width == expectedWidth, "Live status item width changed") }
                if let expectedNeighbor { precondition(neighborWindow.frame == expectedNeighbor, "Neighbor shifted") }
                expectedWidth = width
                expectedNeighbor = neighborWindow.frame
            }
            print("PASS: live NSStatusItem width and neighboring item frame stable across digit, pause, and unavailable states")
        }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            let preview = NSImage(size: NSSize(width: 260, height: 270), flipped: false) { _ in
                NSColor.white.setFill()
                NSRect(x: 0, y: 0, width: 260, height: 270).fill()
                for (index, value) in states.enumerated() {
                    let y = CGFloat(235 - index * 34)
                    (value as NSString).draw(at: NSPoint(x: 12, y: y + 2), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black])
                    let image = MenuBarMeter.image(texts: [value, value, value])
                    image.draw(at: NSPoint(x: 110, y: y), from: .zero, operation: .sourceOver, fraction: 1)
                }
                return true
            }
            let data = bitmap(preview, scale: 2).representation(using: .png, properties: [:])!
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }
        print("PASS: 343 menu-bar state combinations keep \(reference.size.width) × \(reference.size.height) points; percent signs stay aligned at 1× and 2×")
    }

    @MainActor
    static func assertCentered(_ bitmap: NSBitmapImageRep, column: Int, rows: Range<Int>, scale: Int, label: String) {
        let cellWidth = (bitmap.pixelsWide / scale - 16) / 3
        let left = (cellWidth + 8) * column * scale
        let right = left + cellWidth * scale
        let ink = (left..<right).filter { x in
            rows.contains { y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 }
        }
        guard let first = ink.first, let last = ink.last else { fatalError("Missing \(label) pixels") }
        let inkCenter = Double(first + last + 1) / 2
        let cellCenter = Double(left + right) / 2
        precondition(abs(inkCenter - cellCenter) <= 1.5 * Double(scale),
                     "\(label) off center in column \(column), scale \(scale): \(inkCenter) vs \(cellCenter)")
    }

    @MainActor
    static func bitmap(_ image: NSImage, scale: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width) * scale,
                                  pixelsHigh: Int(image.size.height) * scale, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
