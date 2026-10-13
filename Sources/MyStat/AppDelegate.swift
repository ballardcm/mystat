import AppKit
import SwiftUI
import ServiceManagement

private final class SamplingWorker: @unchecked Sendable {
    private var reader: MetricsReader?
    func reset() { reader = nil }
    func sample() -> Metrics {
        if reader == nil { reader = MetricsReader() }
        return reader!.sample()
    }
}

@MainActor
final class Monitor: ObservableObject {
    @Published var metrics = Metrics()
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var interval: Double = 2
    @Published var paused = false
    let hardware = HardwareInfo()
    let panelHeight = min(790.0, max(560.0, (NSScreen.main?.visibleFrame.height ?? 900) - 65))
    var onUpdate: (() -> Void)?
    private let queue = DispatchQueue(label: "io.github.ballardcm.MyStat.sampling", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let worker = SamplingWorker()
    func start() {
        interval = UserDefaults.standard.object(forKey: "interval") as? Double ?? 2
        schedule()
    }
    func setInterval(_ seconds: Double) {
        interval = seconds; UserDefaults.standard.set(seconds, forKey: "interval"); schedule()
    }
    func togglePause() { paused.toggle(); schedule(); onUpdate?() }
    private func schedule() {
        timer?.cancel(); timer = nil
        guard !paused else { return }
        let worker = self.worker
        queue.async { worker.reset() }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            let metrics = worker.sample()
            DispatchQueue.main.async { [weak self] in self?.publish(metrics) }
        }
        self.timer = timer; timer.resume()
    }
    private func publish(_ m: Metrics) {
        guard !paused else { return }
        metrics = m
        func append(_ value: Double?, to history: inout [Double]) {
            if let value { history.append(value); if history.count > 60 { history.removeFirst(history.count - 60) } }
        }
        append(m.cpu, to: &cpuHistory); append(m.memory.pressurePercent, to: &memoryHistory); append(m.gpu, to: &gpuHistory)
        onUpdate?()
    }
}

@MainActor
private final class DashboardPanel: NSPanel {
    var dismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss?() } else { super.keyDown(with: event) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let monitor = Monitor()
    let updates = UpdateController()
    private var item: NSStatusItem!
    private var panel: DashboardPanel!
    private var observers: [NSObjectProtocol] = []
    private var localEvents: Any?
    private var globalEvents: Any?
    private var resumeAfterSleep = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening a bundle should reveal the existing instance, not add another meter.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.ballardcm.MyStat")
        if others.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) { NSApp.terminate(nil); return }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self; button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("MyStat system monitor")
        }
        panel = DashboardPanel(contentRect: NSRect(x: 0, y: 0, width: 424, height: monitor.panelHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "MyStat"
        panel.delegate = self
        panel.isFloatingPanel = true; panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.dismiss = { [weak self] in self?.closePanel() }
        monitor.onUpdate = { [weak self] in self?.updateMenuBar() }
        monitor.start(); updateMenuBar()
        updates.dismissDashboard = { [weak self] in self?.closePanel() }
        updates.start()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        })
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.monitor.paused == false { self?.monitor.togglePause(); self?.resumeAfterSleep = true } }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.resumeAfterSleep == true { self?.resumeAfterSleep = false; if self?.monitor.paused == true { self?.monitor.togglePause() } } }
        })
        #if UI_REVIEW
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.saveSnapshot(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("preview.png").path)
            self.showPanel()
        }
        #endif
        if CommandLine.arguments.contains("--show") { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.showPanel() } }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.indices.contains(index + 1) {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.saveSnapshot(path) }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        if panel.isVisible { closePanel() } else { showPanel() }
    }
    private func showPanel() {
        guard let button = item.button, let statusWindow = button.window else { return }
        if panel.contentViewController == nil {
            panel.contentViewController = NSHostingController(rootView: Dashboard(monitor: monitor, updates: updates, close: { [weak self] in self?.closePanel() }).clipShape(RoundedRectangle(cornerRadius: 14)))
        }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = statusWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let x = min(max(screen.minX + 8, anchor.midX - 212), screen.maxX - 432)
        let y = max(screen.minY + 8, anchor.minY - monitor.panelHeight - 5)
        // Attaching a fresh hosting controller can reset the borderless panel's size.
        panel.setFrame(NSRect(x: x, y: y, width: 424, height: monitor.panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)
        installDismissalMonitors()
        reviewEvent("opened key=\(panel.isKeyWindow)")
    }
    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible, !self.panel.isKeyWindow else { return }
            self.closePanel()
        }
    }
    private func closePanel() {
        guard panel != nil else { return }
        panel.orderOut(nil)
        reviewEvent("closed visible=\(panel.isVisible)")
        removeDismissalMonitors()
        // Release the detail view so hidden charts do not redraw in the background.
        panel.contentViewController = nil
    }
    private func reviewEvent(_ event: String) {
        #if UI_REVIEW
        let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("panel-events.log")
        let line = "\(Date()) \(event)\n"
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + line).write(to: url, atomically: true, encoding: .utf8)
        #endif
    }
    private func installDismissalMonitors() {
        removeDismissalMonitors()
        globalEvents = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
        localEvents = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            let consume = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown && event.keyCode == 53 {
                    self.closePanel(); return true
                }
                if event.type != .keyDown, event.window != self.panel,
                   event.window != self.item.button?.window {
                    self.closePanel()
                }
                return false
            }
            return consume ? nil : event
        }
    }
    private func removeDismissalMonitors() {
        if let localEvents { NSEvent.removeMonitor(localEvents); self.localEvents = nil }
        if let globalEvents { NSEvent.removeMonitor(globalEvents); self.globalEvents = nil }
    }
    private func updateMenuBar() {
        let m = monitor.metrics
        let values = [m.cpu, m.memory.pressurePercent, m.gpu]
        let texts = values.map { monitor.paused ? "Ⅱ" : percent($0) }
        item.button?.image = MenuBarMeter.image(texts: texts)
        item.button?.toolTip = "MyStat · CPU \(percent(m.cpu)) · Memory pressure \(percent(m.memory.pressurePercent)) (\(m.memory.pressure)), \(percent(m.memory.percent)) used · GPU \(percent(m.gpu))"
        item.button?.setAccessibilityValue(item.button?.toolTip)
    }
    private func showMenu() {
        closePanel()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open MyStat", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: monitor.paused ? "Resume monitoring" : "Pause monitoring", action: #selector(pause), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let check = menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self
        check.isEnabled = updates.canCheck
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Quit MyStat", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu; item.button?.performClick(nil); item.menu = nil
    }
    @objc private func openPanel() { showPanel() }
    @objc private func pause() { monitor.togglePause() }
    @objc private func checkForUpdates() { updates.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func saveSnapshot(_ path: String) {
        let controller = NSHostingController(rootView: Dashboard(monitor: monitor, updates: updates))
        let view = controller.view
        view.frame = NSRect(x: 0, y: 0, width: 424, height: monitor.panelHeight)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view; window.appearance = NSAppearance(named: CommandLine.arguments.contains("--snapshot-light") ? .aqua : .darkAqua)
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(monitor.metrics) { try? data.write(to: URL(fileURLWithPath: path + ".json")) }
    }
}
