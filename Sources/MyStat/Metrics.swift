import Foundation
import IOKit
import Darwin

struct CoreLoad: Codable, Identifiable { let id: Int; let usage: Double }
struct MemoryMetrics: Codable {
    var total: Double = 0, app: Double = 0, wired: Double = 0, compressed: Double = 0
    var cached: Double = 0, swapUsed: Double = 0, swapTotal: Double = 0
    var pressure: String = "Unavailable"
    var pressurePercent: Double?
    var used: Double { min(total, app + wired + compressed) }
    var percent: Double? { total > 0 ? used / total * 100 : nil }
}
struct Metrics: Codable {
    var timestamp = Date()
    var sampleDurationMS: Double = 0
    var sampleCPUTimeMS: Double = 0
    var cpu: Double?
    var cores: [CoreLoad] = []
    var memory = MemoryMetrics()
    var gpu: Double?, renderer: Double?, tiler: Double?, gpuMemory: Double?
    var cpuTemperature: Double?, gpuTemperature: Double?
    var cpuPower: Double?, gpuPower: Double?, anePower: Double?, dramPower: Double?, systemPower: Double?
    var batteryPower: Double?, batteryPercent: Double?, onAC = false, charging = false
    var fans: [Double] = []
    var thermalState = "Nominal"
    var powerSource = "Waiting for counters"
}
// Keep only the readings used by the app, not the battery registry's object graph.
struct BatteryReadings {
    let onAC: Bool
    let charging: Bool
    let percent: Double?
    let power: Double?
    let systemPower: Double?

    init(properties: [String: Any]) {
        onAC = (properties["ExternalConnected"] as? Bool) ?? false
        charging = (properties["IsCharging"] as? Bool) ?? false
        percent = (properties["CurrentCapacity"] as? NSNumber)?.doubleValue
        if let voltage = properties["Voltage"] as? NSNumber,
           let amperage = properties["InstantAmperage"] as? NSNumber {
            // The registry may encode a negative signed current as a UInt64.
            let signed = Int64(bitPattern: amperage.uint64Value)
            power = finite(abs(Double(signed) * voltage.doubleValue / 1e6), in: 0...500)
        } else {
            power = nil
        }
        if let telemetry = properties["PowerTelemetryData"] as? [String: Any],
           let milliwatts = telemetry["SystemLoad"] as? NSNumber {
            systemPower = finite(milliwatts.doubleValue / 1000, in: 0.01...500)
        } else {
            systemPower = nil
        }
    }
}
struct HardwareInfo {
    let chip: String
    let coreDescription: String
    let gpuCores: Int?
    init() {
        chip = sysString("machdep.cpu.brand_string") ?? "Apple Silicon"
        var groups: [String] = []
        for i in 0..<4 {
            if let name = sysString("hw.perflevel\(i).name"), let count: Int32 = sysValue("hw.perflevel\(i).physicalcpu") {
                groups.append("\(count) \(name)")
            }
        }
        coreDescription = groups.isEmpty ? "\(ProcessInfo.processInfo.processorCount) CPU cores" : groups.joined(separator: " · ")
        gpuCores = (registryProperties("AGXAccelerator")?["gpu-core-count"] as? NSNumber)?.intValue
    }
}
func sysValue<T>(_ name: String) -> T? {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
    defer { buffer.deallocate() }
    var size = MemoryLayout<T>.size
    guard sysctlbyname(name, buffer, &size, nil, 0) == 0, size == MemoryLayout<T>.size else { return nil }
    return buffer.load(as: T.self)
}
func sysString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
    return String(cString: bytes)
}
func registryProperties(_ name: String) -> [String: Any]? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
    return properties?.takeRetainedValue() as? [String: Any]
}
func registryProperty(_ serviceName: String, _ key: String) -> Any? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}
func processCPUSeconds() -> Double {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
}
func finite(_ value: Double, in range: ClosedRange<Double> = 0...1000) -> Double? {
    value.isFinite && range.contains(value) ? value : nil
}

// All mutable hardware state belongs to the serial sampling queue.
final class MetricsReader {
    private var previousTicks: [UInt32] = []
    private let host = mach_host_self()
    private let smc = msc_open()
    private let power = msp_open(Int32(ProcessInfo.processInfo.operatingSystemVersion.majorVersion))
    private var cpuKeys: [String] = [], gpuKeys: [String] = []
    private var zeroCPUSamples = 0
    private var battery: BatteryReadings?
    private var lastBatteryRead = -Double.infinity
    private(set) var discoveredSensors: [String] = []
    init() {
        if let count = smcValue("#KEY"), count > 0, count < 20000 {
            for index in 0..<UInt32(count) {
                var key = [CChar](repeating: 0, count: 5)
                guard msc_key_at(smc, index, &key) else { continue }
                let name = String(cString: key)
                guard name.hasPrefix("T"), let value = smcValue(name), (5...125).contains(value) else { continue }
                discoveredSensors.append(name)
                if ["Tp", "Te", "Tf", "Ts"].contains(where: name.hasPrefix) { cpuKeys.append(name) }
                if name.hasPrefix("Tg") { gpuKeys.append(name) }
            }
        }
    }
    deinit {
        msc_close(smc); msp_close(power)
        if host != MACH_PORT_NULL { mach_port_deallocate(mach_task_self_, host) }
    }
    func smcValue(_ key: String) -> Double? {
        var value = 0.0
        return key.withCString { msc_read(smc, $0, &value) } ? value : nil
    }
    func sample() -> Metrics {
        // Drain temporary bridged objects after every sample, on every entry path.
        autoreleasepool { readSample() }
    }
    private func readSample() -> Metrics {
        let started = ProcessInfo.processInfo.systemUptime
        let cpuStarted = processCPUSeconds()
        var m = Metrics()
        m.cores = readCPU()
        if !m.cores.isEmpty { m.cpu = m.cores.reduce(0) { $0 + $1.usage } / Double(m.cores.count) }
        m.memory = readMemory()
        if let stats = registryProperty("AGXAccelerator", "PerformanceStatistics") as? [String: Any] {
            func number(_ key: String) -> Double? { (stats[key] as? NSNumber)?.doubleValue }
            m.gpu = number("Device Utilization %").flatMap { finite($0, in: 0...100) }
            m.renderer = number("Renderer Utilization %").flatMap { finite($0, in: 0...100) }
            m.tiler = number("Tiler Utilization %").flatMap { finite($0, in: 0...100) }
            m.gpuMemory = number("In use system memory")
        }
        func hottest(_ keys: [String]) -> Double? { keys.compactMap(smcValue).filter { (5...125).contains($0) }.max() }
        m.cpuTemperature = hottest(cpuKeys); m.gpuTemperature = hottest(gpuKeys)
        for i in 0..<4 { if let rpm = smcValue("F\(i)Ac"), (0...15000).contains(rpm) { m.fans.append(rpm) } }
        let p = msp_sample(power)
        m.cpuPower = finite(p.cpu); m.gpuPower = finite(p.gpu); m.anePower = finite(p.ane); m.dramPower = finite(p.dram)
        // macOS 27 may expose legacy energy channels but stop updating them.
        // A CPU consuming exactly no energy is not a trustworthy measurement.
        if m.cpuPower == 0 { zeroCPUSamples += 1 } else { zeroCPUSamples = 0 }
        if zeroCPUSamples >= 3 {
            // A stalled CPU energy source also invalidates its companion counters.
            m.cpuPower = nil; m.gpuPower = nil; m.anePower = nil; m.dramPower = nil
        }
        m.powerSource = m.cpuPower == nil ? "Chip counters unavailable" : ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 ? "CLPC energy estimates (macOS 27)" : "IOReport energy estimates"
        m.systemPower = smcValue("PSTR").flatMap { finite($0, in: 0.01...500) }
        if m.systemPower != nil { m.powerSource += " · SMC system sensor" }
        if started - lastBatteryRead >= 10 {
            battery = registryProperties("AppleSmartBattery").map { BatteryReadings(properties: $0) }
            lastBatteryRead = started
        }
        if let b = battery {
            m.onAC = b.onAC; m.charging = b.charging
            m.batteryPercent = b.percent; m.batteryPower = b.power
            if m.systemPower == nil, let systemPower = b.systemPower {
                m.systemPower = systemPower
                m.powerSource += " · battery-controller system load"
            }
        }
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: m.thermalState = "Nominal"
        case .fair: m.thermalState = "Warm"
        case .serious: m.thermalState = "High"
        case .critical: m.thermalState = "Critical"
        @unknown default: m.thermalState = "Unknown"
        }
        m.sampleCPUTimeMS = (processCPUSeconds() - cpuStarted) * 1000
        m.sampleDurationMS = (ProcessInfo.processInfo.systemUptime - started) * 1000
        return m
    }
    private func readCPU() -> [CoreLoad] {
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0, processors: natural_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processors, &info, &count) == KERN_SUCCESS, let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.size)) }
        let ticks = (0..<Int(count)).map { UInt32(bitPattern: info[$0]) }
        defer { previousTicks = ticks }
        guard previousTicks.count == ticks.count else { return [] }
        return (0..<Int(processors)).map { core in
            let offset = core * Int(CPU_STATE_MAX)
            let delta = (0..<Int(CPU_STATE_MAX)).map { UInt64(ticks[offset + $0] &- previousTicks[offset + $0]) }
            let total = delta.reduce(0, +), idle = delta[Int(CPU_STATE_IDLE)]
            return CoreLoad(id: core, usage: total > 0 ? Double(total - idle) / Double(total) * 100 : 0)
        }
    }
    private func readMemory() -> MemoryMetrics {
        var m = MemoryMetrics()
        // The same availability counter used by `memory_pressure -Q`.
        // Keep this separate from physical RAM usage and the severity level.
        // Missing or changed counters must not silently fall back to RAM usage.
        if let available: Int32 = sysValue("kern.memorystatus_level"), (0...100).contains(available) {
            m.pressurePercent = Double(100 - available)
        }
        if let pressure: Int32 = sysValue("kern.memorystatus_vm_pressure_level") {
            m.pressure = pressure == 1 ? "Normal" : pressure == 2 ? "Elevated" : pressure == 4 ? "Critical" : "Unknown"
        }
        m.total = Double(ProcessInfo.processInfo.physicalMemory)
        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { m.total = 0; return m }
        let page = Double(vm_kernel_page_size)
        m.app = Double(vm.internal_page_count > vm.purgeable_count ? vm.internal_page_count - vm.purgeable_count : 0) * page
        m.wired = Double(vm.wire_count) * page; m.compressed = Double(vm.compressor_page_count) * page
        m.cached = (Double(vm.external_page_count) + Double(vm.purgeable_count)) * page
        if let swap: xsw_usage = sysValue("vm.swapusage") { m.swapUsed = Double(swap.xsu_used); m.swapTotal = Double(swap.xsu_total) }
        return m
    }
}
