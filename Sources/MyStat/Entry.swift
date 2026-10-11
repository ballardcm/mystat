import AppKit

@main
struct MyStatApp {
@MainActor static func main() {
if CommandLine.arguments.contains("--diagnose") {
    let reader = MetricsReader()
    _ = reader.sample()
    Thread.sleep(forTimeInterval: 2)
    let sample = reader.sample()
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(sample), let string = String(data: data, encoding: .utf8) { print(string) }
    print("Temperature sensors: \(reader.discoveredSensors.joined(separator: ", "))")
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

}
}
