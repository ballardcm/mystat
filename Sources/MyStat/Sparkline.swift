import AppKit
import SwiftUI

// Keep these small charts on AppKit's drawing path. A SwiftUI Canvas for each
// card incurred substantial graphics allocations while the dashboard was open.
struct Sparkline: NSViewRepresentable {
    let values: [Double]
    let color: Color

    func makeNSView(context: Context) -> SparklineView { SparklineView() }

    func updateNSView(_ view: SparklineView, context: Context) {
        view.update(values: values, color: NSColor(color))
    }
}

struct SparklineSamples: Equatable {
    let values: [Double?]

    init(_ values: [Double]) {
        self.values = values.suffix(60).map { $0.isFinite ? min(100, max(0, $0)) : nil }
    }

    func segments(in size: CGSize) -> [[CGPoint]] {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height >= 3 else { return [] }
        var result: [[CGPoint]] = []
        var segment: [CGPoint] = []
        for (index, value) in values.enumerated() {
            if let value {
                segment.append(CGPoint(x: size.width * CGFloat(60 - values.count + index) / 59,
                                       y: 1 + (size.height - 3) * (1 - value / 100)))
            } else {
                if segment.count > 1 { result.append(segment) }
                segment.removeAll(keepingCapacity: true)
            }
        }
        if segment.count > 1 { result.append(segment) }
        return result
    }
}

final class SparklineView: NSView {
    private var samples = SparklineSamples([])
    private var color = NSColor.clear
    override var isFlipped: Bool { true }

    func update(values: [Double], color: NSColor) {
        let next = SparklineSamples(values)
        guard next != samples || color != self.color else { return }
        samples = next
        self.color = color
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height >= 3,
              let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: bounds)
        context.setStrokeColor(color.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: 0, y: bounds.height - 1))
        context.addLine(to: CGPoint(x: bounds.width, y: bounds.height - 1))
        context.strokePath()

        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [color.withAlphaComponent(0.18).cgColor,
                                           color.withAlphaComponent(0.01).cgColor] as CFArray,
                                  locations: [0, 1])
        for points in samples.segments(in: bounds.size) {
            let line = CGMutablePath()
            line.addLines(between: points)
            if let fill = line.mutableCopy(), let first = points.first, let last = points.last,
               let gradient {
                fill.addLine(to: CGPoint(x: last.x, y: bounds.height))
                fill.addLine(to: CGPoint(x: first.x, y: bounds.height))
                fill.closeSubpath()
                context.saveGState()
                context.addPath(fill)
                context.clip()
                context.drawLinearGradient(gradient, start: .zero,
                                           end: CGPoint(x: 0, y: bounds.height), options: [])
                context.restoreGState()
            }
            context.addPath(line)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.3)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }
}
