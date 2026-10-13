import AppKit

@main
struct DashboardPlacementTests {
    static func main() {
        // Opening after a VM resize or on another display must use that display's
        // current coordinates, including negative origins and a Dock inset.
        for screen in [
            NSRect(x: 0, y: 70, width: 1440, height: 805),
            NSRect(x: 0, y: 60, width: 800, height: 515),
            NSRect(x: -1920, y: -300, width: 1920, height: 1055),
            NSRect(x: 1440, y: 110, width: 1024, height: 633)
        ] {
            for center in [screen.minX + 50, screen.midX, screen.maxX - 50] {
                let anchor = NSRect(x: center - 60, y: screen.maxY, width: 120, height: 25)
                let frame = DashboardPlacement.frame(anchor: anchor, visibleFrame: screen)
                precondition(frame.minX >= screen.minX + 8 && frame.maxX <= screen.maxX - 8)
                precondition(frame.minY >= screen.minY + 8 && frame.maxY <= screen.maxY - 8)
                precondition(frame.maxY <= anchor.minY - 5)
                precondition(frame.width == 424 && frame.height <= 790)
                if center == screen.midX { precondition(frame.midX == center) }
            }
        }
        let large = NSRect(x: 0, y: 0, width: 1440, height: 1000)
        let small = NSRect(x: 0, y: 0, width: 800, height: 500)
        let largeFrame = DashboardPlacement.frame(anchor: NSRect(x: 1000, y: 1000, width: 120, height: 25), visibleFrame: large)
        let smallFrame = DashboardPlacement.frame(anchor: NSRect(x: 600, y: 500, width: 120, height: 25), visibleFrame: small)
        precondition(largeFrame.height == 790 && smallFrame.height == 484)
        print("PASS: dashboard fits current display after resizing, with edge anchors, Dock insets, and multiple-screen origins")
    }
}
