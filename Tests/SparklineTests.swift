import AppKit

@main
struct SparklineTests {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let size = CGSize(width: 118, height: 20)
        precondition(SparklineSamples([]).segments(in: size).isEmpty)
        precondition(SparklineSamples([50]).segments(in: size).isEmpty)
        let full = SparklineSamples(Array(repeating: 0, count: 59) + [100]).segments(in: size)[0]
        precondition(full.count == 60 && full.first == CGPoint(x: 0, y: 18))
        precondition(full.last == CGPoint(x: 118, y: 1))
        let partial = SparklineSamples([0, 100]).segments(in: size)[0]
        precondition(partial == [CGPoint(x: 116, y: 18), CGPoint(x: 118, y: 1)],
                     "Partial histories must remain right-aligned on the 60-sample axis")
        let capped = SparklineSamples(Array(repeating: -50, count: 20) + Array(repeating: 150, count: 60))
        precondition(capped.values.count == 60 && capped.values.allSatisfy { $0 == 100 })
        let invalid = SparklineSamples([0, 10, .nan, 20, 30, .infinity, -.infinity, 40])
        let segments = invalid.segments(in: size)
        precondition(segments.map(\.count) == [2, 2], "Missing data must not join across gaps")
        precondition(invalid == SparklineSamples([0, 10, .nan, 20, 30, .infinity, -.infinity, 40]))
        for invalidSize in [CGSize.zero, CGSize(width: 10, height: 2),
                            CGSize(width: CGFloat.infinity, height: 20), CGSize(width: 10, height: CGFloat.nan)] {
            precondition(capped.segments(in: invalidSize).isEmpty)
        }

        let view = SparklineView(frame: CGRect(origin: .zero, size: size))
        for scale in [1, 2] {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                view.appearance = NSAppearance(named: appearance)
                // Test the production NSView's drawing code in a transparent bitmap.
                let empty = render(view, values: [], scale: scale)
                let high = render(view, values: Array(repeating: 100, count: 60), scale: scale)
                let low = render(view, values: Array(repeating: 0, count: 60), scale: scale)
                precondition(ink(empty) > 0, "Empty history must retain its baseline")
                precondition(ink(high) > ink(low) * 2, "High values must retain the gradient area fill")
                let gap = render(view, values: Array(repeating: 100, count: 20) + [.nan] + Array(repeating: 100, count: 39), scale: scale)
                // The missing point is at x=40; the baseline is the only ink in this gap.
                var gapAlpha = 0.0
                for y in 0..<(20 * scale) { gapAlpha += gap.colorAt(x: 40 * scale, y: y)!.alphaComponent }
                precondition(gapAlpha < Double(scale), "Chart fill must not bridge missing samples")
                precondition(ink(high) > ink(empty) * 2)
            }
        }
        print("PASS: sparklines preserve geometry, gaps, bounded history, and light/dark 1x/2x drawing")
    }

    @MainActor
    static func render(_ view: SparklineView, values: [Double], scale: Int) -> NSBitmapImageRep {
        view.update(values: values, color: NSColor(calibratedRed: 0.33, green: 0.72, blue: 1, alpha: 1))
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 118 * scale, pixelsHigh: 20 * scale,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = view.bounds.size
        rep.bitmapData!.initialize(repeating: 0, count: rep.bytesPerRow * rep.pixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = graphics
        let c = graphics.cgContext
        c.concatenate(c.ctm.inverted())
        c.clear(CGRect(x: 0, y: 0, width: 118 * scale, height: 20 * scale))
        c.translateBy(x: 0, y: CGFloat(20 * scale))
        c.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func ink(_ rep: NSBitmapImageRep) -> Double {
        var result = 0.0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh { result += rep.colorAt(x: x, y: y)!.alphaComponent }
        }
        return result
    }
}
