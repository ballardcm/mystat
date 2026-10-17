import Foundation
import Darwin

@main
struct MetricsTests {
    static func hostReferences(_ host: mach_port_t) -> mach_port_urefs_t {
        var count: mach_port_urefs_t = 0
        precondition(mach_port_get_refs(mach_task_self_, host, MACH_PORT_RIGHT_SEND, &count) == KERN_SUCCESS)
        return count
    }

    static func main() {
        let missing = BatteryReadings(properties: [:])
        precondition(!missing.onAC && !missing.charging)
        precondition(missing.percent == nil && missing.power == nil && missing.systemPower == nil)

        for current in [NSNumber(value: -2000), NSNumber(value: UInt64(bitPattern: -2000)), NSNumber(value: 2000)] {
            let battery = BatteryReadings(properties: [
                "ExternalConnected": true, "IsCharging": false, "CurrentCapacity": 73,
                "Voltage": 12000, "InstantAmperage": current,
                "PowerTelemetryData": ["SystemLoad": 34500]
            ])
            precondition(battery.onAC && !battery.charging && battery.percent == 73)
            precondition(battery.power == 24 && battery.systemPower == 34.5,
                         "Signed or unsigned-encoded current changed battery watts")
        }
        let zero = BatteryReadings(properties: [
            "Voltage": 12000, "InstantAmperage": 0, "PowerTelemetryData": ["SystemLoad": 0]
        ])
        precondition(zero.power == 0 && zero.systemPower == nil,
                     "Zero battery draw is valid; zero system load is unavailable")
        for value in [Double.nan, Double.infinity, -1000, 500001] {
            let battery = BatteryReadings(properties: ["PowerTelemetryData": ["SystemLoad": value]])
            precondition(battery.systemPower == nil, "Invalid system power must remain unavailable")
        }
        let excessive = BatteryReadings(properties: ["Voltage": 12000, "InstantAmperage": 1000000])
        precondition(excessive.power == nil)
        let malformed = BatteryReadings(properties: [
            "Voltage": "unknown", "InstantAmperage": 2000,
            "PowerTelemetryData": ["SystemLoad": "unknown"]
        ])
        precondition(malformed.power == nil && malformed.systemPower == nil)

        weak var unusedProperty: NSData?
        let extracted = autoreleasepool {
            let data = NSMutableData(length: 65536)!
            unusedProperty = data
            return BatteryReadings(properties: ["UnusedDiagnosticData": data, "CurrentCapacity": 50])
        }
        precondition(extracted.percent == 50 && unusedProperty == nil,
                     "Typed battery cache retained an unrelated registry object")

        // Exercise real Mach ownership, including repeated samples and reader resets.
        // Available sensor values are not asserted: this is not accuracy validation.
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        for _ in 0..<3 {
            var ownedReferences: mach_port_urefs_t = 0
            autoreleasepool {
                let reader = MetricsReader()
                // System frameworks may acquire their own process-wide rights on
                // first use. Check stability after initialization, then our release.
                _ = reader.sample()
                ownedReferences = hostReferences(host)
                for _ in 0..<8 {
                    _ = reader.sample()
                    precondition(hostReferences(host) == ownedReferences,
                                 "Sampling leaked a host port reference")
                }
                withExtendedLifetime(reader) {}
            }
            precondition(hostReferences(host) == ownedReferences - 1,
                         "Releasing a reader leaked its host port reference")
        }
        print("PASS: battery decoding, unavailable/invalid values, registry object release, and stable Mach host ownership across sampling/reset.")
    }
}
