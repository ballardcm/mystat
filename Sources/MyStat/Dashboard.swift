import SwiftUI
import AppKit
import ServiceManagement

func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", $0) } ?? "—" }
func watts(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "—" }
func temperature(_ value: Double?) -> String { value.map { String(format: "%.0f°", $0) } ?? "—" }
func gigabytes(_ value: Double) -> String { String(format: "%.1f GB", value / 1_073_741_824) }
private let cpuColor = Color(red: 0.33, green: 0.72, blue: 1)
private let memoryColor = Color(red: 0.69, green: 0.57, blue: 1)
private let gpuColor = Color(red: 0.27, green: 0.85, blue: 0.69)

struct Dashboard: View {
    @ObservedObject var monitor: Monitor
    var close: () -> Void = {}
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var showInfo = false
    @Environment(\.colorScheme) private var scheme
    private var m: Metrics { monitor.metrics }
    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    overview
                    cpuSection
                    memorySection
                    gpuSection
                    powerSection
                    if showInfo { infoSection }
                }.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 16)
            }.scrollIndicators(.hidden)
            footer
        }
        .frame(width: 424, height: monitor.panelHeight)
        .background(scheme == .dark ? Color(red: 0.085, green: 0.095, blue: 0.115) : Color(red: 0.96, green: 0.965, blue: 0.975))
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: "waveform.path").font(.system(size: 16, weight: .semibold)).foregroundStyle(cpuColor)
                    Text("MyStat").font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                Text(monitor.hardware.chip + " · " + gigabytes(m.memory.total).replacingOccurrences(of: ".0", with: ""))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(monitor.paused ? Color.orange : gpuColor).frame(width: 5, height: 5)
                Text(monitor.paused ? "PAUSED" : "LIVE").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
            }.padding(.horizontal, 9).padding(.vertical, 6).background(.primary.opacity(0.045), in: Capsule())
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).frame(width: 22, height: 24) }
                .buttonStyle(.plain).help("Close MyStat").accessibilityLabel("Close MyStat")
        }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }
    private var overview: some View {
        HStack(spacing: 8) {
            MetricCard(title: "CPU", value: percent(m.cpu), history: monitor.cpuHistory, color: cpuColor)
            MetricCard(title: "PRESSURE", value: percent(m.memory.pressurePercent), history: monitor.memoryHistory, color: memoryColor)
                .help("Memory pressure. Lower means more available memory headroom.")
            MetricCard(title: "GPU", value: percent(m.gpu), history: monitor.gpuHistory, color: gpuColor)
        }
    }
    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("CPU", subtitle: "\(m.cores.count) cores", icon: "cpu", color: cpuColor, temp: m.cpuTemperature)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 9), spacing: 9) {
                ForEach(m.cores) { core in
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3).fill(cpuColor.opacity(0.08))
                                RoundedRectangle(cornerRadius: 3).fill(cpuColor.opacity(0.8)).frame(height: max(2, geo.size.height * core.usage / 100))
                                Text(String(format: "%.0f", core.usage)).font(.system(size: 9, weight: .medium, design: .monospaced)).frame(maxHeight: .infinity)
                            }
                        }.frame(height: 29)
                        Text(String(format: "%02d", core.id + 1)).font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary)
                    }.help("Core \(core.id + 1): \(percent(core.usage)) busy")
                    .accessibilityElement(children: .ignore).accessibilityLabel("Core \(core.id + 1)").accessibilityValue(percent(core.usage))
                }
            }
            Text(monitor.hardware.coreDescription).font(.system(size: 10)).foregroundStyle(.secondary)
        }.card()
    }
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Memory · \(percent(m.memory.percent)) used", systemImage: "memorychip").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(gigabytes(m.memory.used)) / \(gigabytes(m.memory.total))").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array([m.memory.app, m.memory.wired, m.memory.compressed].enumerated()), id: \.offset) { index, value in
                        Rectangle().fill([memoryColor, memoryColor.opacity(0.65), memoryColor.opacity(0.35)][index])
                            .frame(width: max(0, (geo.size.width - 6) * value / max(1, m.memory.total)))
                    }
                    Spacer(minLength: 0)
                }.frame(height: 6).background(memoryColor.opacity(0.08)).clipShape(Capsule())
            }.frame(height: 6)
            HStack(spacing: 0) {
                memoryItem("App", m.memory.app, memoryColor)
                memoryItem("Wired", m.memory.wired, memoryColor.opacity(0.65))
                memoryItem("Compressed", m.memory.compressed, memoryColor.opacity(0.35))
            }
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(m.memory.pressure == "Normal" ? gpuColor : m.memory.pressure == "Critical" ? Color.red : m.memory.pressure == "Elevated" ? Color.orange : Color.gray).frame(width: 4, height: 4)
                    Text("\(percent(m.memory.pressurePercent)) pressure · \(m.memory.pressure)")
                }
                Spacer()
                Text("Swap " + gigabytes(m.memory.swapUsed))
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.card()
        .help("Used = app + wired + compressed physical memory. File cache: \(gigabytes(m.memory.cached)). Memory is shared with the GPU; do not add GPU memory to this total.")
    }
    private var gpuSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("GPU", subtitle: monitor.hardware.gpuCores.map { "\($0) cores" } ?? "Unified", icon: "square.3.layers.3d", color: gpuColor, temp: m.gpuTemperature)
            HStack(spacing: 0) {
                smallStat("Renderer", percent(m.renderer))
                smallStat("Tiler", percent(m.tiler))
                smallStat("Memory in use", m.gpuMemory.map(gigabytes) ?? "—")
            }
        }.card()
    }
    private var powerSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Power", systemImage: "bolt").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(m.onAC ? "Plugged in" : "On battery").font(.system(size: 10)).foregroundStyle(.secondary)
                Image(systemName: m.onAC ? "powerplug" : "battery.75percent").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(watts(m.systemPower)).font(.system(size: 27, weight: .light, design: .rounded)).monospacedDigit()
                        Text("W").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Text("Entire Mac").font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                powerItem("CPU", m.cpuPower)
                powerItem("GPU", m.gpuPower)
                powerItem("Neural", m.anePower)
            }
            Divider().opacity(0.5)
            HStack {
                Label(m.thermalState, systemImage: "thermometer.medium")
                Spacer()
                if !m.fans.isEmpty {
                    Text(m.fans.map { String(format: "%.0f", $0) }.joined(separator: " / ") + " rpm")
                    Image(systemName: "fanblades")
                }
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.card().help(m.powerSource + ". Chip values are estimates; Entire Mac includes display, memory and other components. Temperatures show the hottest readable CPU/GPU sensor.")
    }
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About these readings").font(.system(size: 12, weight: .semibold))
            Text("CPU is busy time across all cores. Menu-bar MEM and the pressure chart show memory pressure; lower means more headroom. Memory used is shown separately and includes app, wired and compressed memory. GPU is driver-reported device utilization. Charts show the last 60 samples.")
            Text("Temperatures show the hottest readable die sensor. Power is estimated; component watts need not add up to the entire Mac. A dash means that macOS did not provide a usable reading.")
            Text("Sensor and power interfaces are private Apple APIs and can change with macOS updates. Built for and tested on macOS 26. macOS 27 support is planned for a later update. Unknown counters are shown as unavailable.")
            Text("\(ProcessInfo.processInfo.operatingSystemVersionString) · refresh \(Int(monitor.interval))s")
            Text(m.powerSource)
            Text("Cache: \(gigabytes(m.memory.cached)) · Battery: \(percent(m.batteryPercent)) · \(m.charging ? "Charging" : m.onAC ? "AC connected" : "Discharging") \(watts(m.batteryPower)) W")
        }.font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).card()
    }
    private var footer: some View {
        HStack {
            Menu {
                ForEach([1.0, 2.0, 5.0], id: \.self) { seconds in
                    Button { monitor.setInterval(seconds) } label: { Text("\(Int(seconds)) seconds" + (monitor.interval == seconds ? " ✓" : "")) }
                }
            } label: { Text("\(Int(monitor.interval))s refresh").font(.system(size: 10)) }.menuStyle(.borderlessButton).fixedSize()
            Spacer()
            Button { withAnimation { showInfo.toggle() } } label: { Image(systemName: "info.circle") }.help("About these readings")
            Button { monitor.togglePause() } label: { Image(systemName: monitor.paused ? "play" : "pause") }.help(monitor.paused ? "Resume monitoring" : "Pause monitoring")
            Menu {
                Toggle("Launch at login", isOn: Binding(get: { loginEnabled }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginEnabled = SMAppService.mainApp.status == .enabled
                        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                    } catch { loginError = error.localizedDescription }
                }))
                Button("Open Activity Monitor") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")) }
                Divider()
                Button("Quit MyStat") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "gearshape") }.menuStyle(.borderlessButton).fixedSize().help("Settings")
        }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 13)
        .background(.primary.opacity(0.025))
        .alert("Login item could not be changed", isPresented: Binding(get: { loginError != nil }, set: { if !$0 { loginError = nil } })) { Button("OK") { loginError = nil } } message: { Text(loginError ?? "") }
    }
    private func sectionTitle(_ title: String, subtitle: String, icon: String, color: Color, temp: Double?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).fontWeight(.semibold)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Text(temperature(temp)).monospacedDigit().foregroundStyle(.secondary)
            Image(systemName: "thermometer.medium").font(.system(size: 10)).foregroundStyle(.tertiary)
        }.font(.system(size: 12)).help("Hottest readable \(title) die temperature in °C")
    }
    private func memoryItem(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) { Circle().fill(color).frame(width: 4, height: 4); Text(label).font(.system(size: 9)).foregroundStyle(.secondary) }
            Text(gigabytes(value)).font(.system(size: 11, weight: .medium, design: .monospaced))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func smallStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func powerItem(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(watts(value) + " W").font(.system(size: 12, weight: .medium, design: .monospaced))
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .trailing)
    }
}
private struct MetricCard: View {
    let title: String, value: String
    let history: [Double]
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(color)
            Text(value).font(.system(size: 27, weight: .light, design: .rounded)).monospacedDigit()
            Sparkline(values: history, color: color).frame(height: 20)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.13), lineWidth: 0.5))
        .accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityValue(value)
    }
}
private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var body: some View {
        Canvas { context, size in
            var baseline = Path(); baseline.move(to: CGPoint(x: 0, y: size.height - 1)); baseline.addLine(to: CGPoint(x: size.width, y: size.height - 1))
            context.stroke(baseline, with: .color(color.opacity(0.15)), lineWidth: 1)
            guard values.count > 1 else { return }
            var line = Path()
            let points = values.enumerated().map { i, value in CGPoint(x: size.width * CGFloat(60 - values.count + i) / 59, y: 1 + (size.height - 3) * (1 - value / 100)) }
            line.addLines(points)
            var fill = line
            fill.addLine(to: CGPoint(x: points.last!.x, y: size.height)); fill.addLine(to: CGPoint(x: points.first!.x, y: size.height)); fill.closeSubpath()
            context.fill(fill, with: .linearGradient(Gradient(colors: [color.opacity(0.18), color.opacity(0.01)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
private extension View {
    func card() -> some View {
        self.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.07), lineWidth: 0.5))
    }
}
