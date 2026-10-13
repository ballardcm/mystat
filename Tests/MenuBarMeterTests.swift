import AppKit

@main
struct MenuBarMeterTests {
    @MainActor
    static func main() throws {
        let states = ["0%", "9%", "10%", "99%", "100%", "Ⅱ", "—"]
        let reference = MenuBarMeter.image(texts: ["100%", "100%", "100%"])
        precondition(reference.size == NSSize(width: 89, height: 22), "Compact meter geometry changed")
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
        // Inspect the actual ink: a stable image size alone cannot verify centering.
        for scale in [1, 2] {
            for value in states {
                let rendered = bitmap(MenuBarMeter.image(texts: [value, value, value]), scale: scale)
                for column in 0..<3 {
                    let left = (27 + 4) * column * scale
                    let right = left + 27 * scale
                    let cellCenter = Double(left + right) / 2
                    for (label, rows) in [("Caption", 0..<10 * scale), (value, 10 * scale..<22 * scale)] {
                        let bounds = inkBounds(rendered, column: column, rows: rows, scale: scale, label: label)
                        let inkCenter = Double(bounds.lowerBound + bounds.upperBound) / 2
                        precondition(abs(inkCenter - cellCenter) <= 1.5 * Double(scale),
                                     "\(label) off center in column \(column), scale \(scale): \(inkCenter) vs \(cellCenter)")
                        precondition(bounds.lowerBound >= left && bounds.upperBound <= right,
                                     "\(label) leaves column bounds in column \(column), scale \(scale)")
                    }
                }
                // Every column displays the same glyph, so transparent interior gaps
                // also catch overflow that would be cropped at the image's outer edges.
                for column in 0..<2 {
                    let gapStart = ((27 + 4) * column + 27) * scale
                    for x in gapStart..<(gapStart + 4 * scale) {
                        for y in 0..<22 * scale {
                            precondition((rendered.colorAt(x: x, y: y)?.alphaComponent ?? 0) <= 0.1,
                                         "\(value) spills into column gap at scale \(scale)")
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
            var expectedFrame: NSRect?
            var expectedButton: NSRect?
            var expectedNeighbor: NSRect?
            let transitions = states + states.reversed()
            let readings = transitions.map { [$0, $0, $0] } + (0..<3).flatMap { column in
                transitions.map { value -> [String] in
                    var texts = ["9%", "10%", "—"]
                    texts[column] = value
                    return texts
                }
            }
            for texts in readings {
                item.button?.image = MenuBarMeter.image(texts: texts)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
                guard let button = item.button, let window = button.window,
                      let neighborWindow = neighbor.button?.window else {
                    fatalError("Live status items unavailable")
                }
                let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
                if let expectedFrame { precondition(window.frame == expectedFrame, "Live status item moved or resized for \(texts)") }
                if let expectedButton { precondition(buttonFrame == expectedButton, "Live button moved or resized for \(texts)") }
                if let expectedNeighbor { precondition(neighborWindow.frame == expectedNeighbor, "Neighbor shifted") }
                expectedFrame = window.frame
                expectedButton = buttonFrame
                expectedNeighbor = neighborWindow.frame
            }
            print("PASS: \(readings.count) live transitions keep status item, button, and neighbor frames stable")
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
        print("PASS: 343 menu-bar state combinations keep \(reference.size.width) × \(reference.size.height) points; captions and values stay centered without clipping at 1× and 2×")
        if CommandLine.arguments.contains("--review") {
            let review = MeterReview()
            review.run()
        }
    }

    @MainActor
    static func inkBounds(_ bitmap: NSBitmapImageRep, column: Int, rows: Range<Int>, scale: Int, label: String) -> Range<Int> {
        let cellWidth = (bitmap.pixelsWide / scale - 8) / 3
        let left = (cellWidth + 4) * column * scale
        let right = left + cellWidth * scale
        let ink = (left..<right).filter { x in
            rows.contains { y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 }
        }
        guard let first = ink.first, let last = ink.last else { fatalError("Missing \(label) pixels") }
        return first..<(last + 1)
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

// Manual fixture only: the shipping app never accepts synthetic sensor readings.
@MainActor
final class MeterReview: NSObject, NSWindowDelegate {
    private let cases: [(String, [String])] = [
        ("Single digits", ["5%", "7%", "9%"]),
        ("Two digits", ["10%", "17%", "99%"]),
        ("Maximum", ["100%", "100%", "100%"]),
        ("Mixed digits", ["9%", "10%", "100%"]),
        ("Mixed states", ["—", "17%", "Ⅱ"]),
        ("Paused", ["Ⅱ", "Ⅱ", "Ⅱ"]),
        ("Unavailable", ["—", "—", "—"])
    ]
    private var item: NSStatusItem?
    private var neighbor: NSStatusItem?
    private var window: NSWindow!
    private var imageViews: [(NSImageView, Int)] = []
    private var reading: NSTextField!
    private var geometry: NSTextField!

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        neighbor = NSStatusBar.system.statusItem(withLength: 20)
        neighbor?.button?.title = "·"
        item?.button?.toolTip = "MyStat layout review fixture"
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MyStat meter layout review"
        window.delegate = self
        window.isReleasedWhenClosed = false
        let content = window.contentView!
        addLabel("Choose a reading; inspect the real meter beside the · marker.", x: 20, y: 394, width: 520)
        reading = addLabel("", x: 20, y: 362, width: 520, bold: true)
        for (index, entry) in cases.enumerated() {
            let button = NSButton(title: entry.0, target: self, action: #selector(selectState(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            button.frame = NSRect(x: 20 + (index % 4) * 130, y: 314 - (index / 4) * 36, width: 124, height: 30)
            content.addSubview(button)
        }
        for (index, dark) in [false, true].enumerated() {
            let box = NSBox(frame: NSRect(x: 20 + index * 270, y: 114, width: 250, height: 140))
            box.boxType = .custom
            box.borderWidth = 0
            box.fillColor = dark ? NSColor(calibratedWhite: 0.18, alpha: 1) : .white
            box.cornerRadius = 8
            box.contentViewMargins = .zero
            content.addSubview(box)
            let caption = NSTextField(labelWithString: dark ? "Dark appearance" : "Light appearance")
            caption.font = .systemFont(ofSize: 12, weight: .semibold)
            caption.textColor = dark ? .white : .black
            caption.frame = NSRect(x: 12, y: 108, width: 220, height: 20)
            box.contentView?.addSubview(caption)
            for scale in [1, 2] {
                let label = NSTextField(labelWithString: "\(scale)× raster")
                label.font = .systemFont(ofSize: 11)
                label.textColor = dark ? .white : .black
                label.frame = NSRect(x: 12, y: 72 - (scale - 1) * 40, width: 88, height: 20)
                box.contentView?.addSubview(label)
                let view = NSImageView(frame: NSRect(x: 112, y: 72 - (scale - 1) * 40, width: 89, height: 22))
                view.imageScaling = .scaleNone
                view.contentTintColor = dark ? .white : .black
                box.contentView?.addSubview(view)
                imageViews.append((view, scale))
            }
        }
        geometry = addLabel("", x: 20, y: 78, width: 520)
        addLabel("Both rasters retain the actual 89 × 22 point footprint.\nClose this window to remove both fixture menu-bar items.", x: 20, y: 22, width: 520, height: 44)
        setState(0)
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        defer { removeItems() }
        app.run()
    }

    @discardableResult
    private func addLabel(_ text: String, x: Int, y: Int, width: Int, height: Int = 24, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: bold ? 15 : 12, weight: bold ? .semibold : .regular)
        label.frame = NSRect(x: x, y: y, width: width, height: height)
        window.contentView?.addSubview(label)
        return label
    }

    @objc private func selectState(_ sender: NSButton) { setState(sender.tag) }

    private func setState(_ index: Int) {
        let entry = cases[index]
        let image = MenuBarMeter.image(texts: entry.1)
        item?.button?.image = image
        reading.stringValue = "\(entry.0): CPU \(entry.1[0])  ·  MEM \(entry.1[1])  ·  GPU \(entry.1[2])"
        for (view, scale) in imageViews {
            let raster = NSImage(size: image.size)
            raster.addRepresentation(MenuBarMeterTests.bitmap(image, scale: scale))
            raster.isTemplate = true
            view.image = raster
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, let frame = self.item?.button?.window?.frame else { return }
            self.geometry.stringValue = "Status item frame: x \(Int(frame.minX)), y \(Int(frame.minY)), width \(Int(frame.width))"
            print("REVIEW: \(entry.0), readings \(entry.1), frame \(frame)")
        }
    }

    private func removeItems() {
        if let item { NSStatusBar.system.removeStatusItem(item); self.item = nil }
        if let neighbor { NSStatusBar.system.removeStatusItem(neighbor); self.neighbor = nil }
    }

    func windowWillClose(_ notification: Notification) {
        removeItems()
        NSApp.stop(nil)
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
                                         windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
            NSApp.postEvent(event, atStart: true)
        }
    }
}
