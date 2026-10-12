import Foundation
import Sparkle

@main
struct UpdateTests {
    static func main() throws {
        func accepts(_ version: String = "0.2.0", build: String = "3", current: String = "0.1.1", currentBuild: String = "2",
                     url: String? = nil, type: String = "application", channel: String? = nil) -> Bool {
            UpdatePolicy.accepts(version: version, build: build, currentVersion: current, currentBuild: currentBuild,
                downloadURL: URL(string: url ?? "https://github.com/ballardcm/mystat/releases/download/v\(version)/MyStat-\(version)-macos-arm64.zip"), installationType: type, channel: channel)
        }
        precondition(accepts())
        precondition(accepts("0.10.0"))
        precondition(!accepts("0.1.1"))
        precondition(!accepts("0.1.0"))
        precondition(!accepts(build: "2"))
        precondition(!accepts(build: "1"))
        precondition(!accepts("0.2.0-beta.1"))
        precondition(!accepts(build: "3b1"))
        precondition(!accepts(current: "unknown"))
        precondition(!accepts(channel: "beta"))
        precondition(!accepts(type: "package"))
        precondition(!accepts(url: "https://github.com/attacker/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-arm64.zip"))
        precondition(!accepts(url: "https://github.com.evil.example/ballardcm/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-arm64.zip"))
        precondition(!accepts(url: "http://github.com/ballardcm/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-arm64.zip"))
        precondition(!accepts(url: "https://github.com/ballardcm/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-arm64.zip?redirect=evil"))
        precondition(!accepts(url: "https://github.com/ballardcm/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-intel.zip"))
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("MyStat.app")
        try fm.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        precondition(UpdatePolicy.installationError(at: app, osMajor: 26) == nil)
        precondition(UpdatePolicy.installationError(at: app, osMajor: 27) == nil)
        precondition(UpdatePolicy.installationError(at: app, osMajor: 25) != nil)
        precondition(UpdatePolicy.installationError(at: app, osMajor: 28) != nil)
        precondition(UpdatePolicy.installationError(at: app, osMajor: 15) != nil)
        for osMajor in [26, 27] {
            let link = root.appendingPathComponent("Alias-\(osMajor).app")
            try fm.createSymbolicLink(at: link, withDestinationURL: app)
            precondition(UpdatePolicy.installationError(at: link, osMajor: osMajor) != nil)
            try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.path)
            precondition(UpdatePolicy.installationError(at: app, osMajor: osMajor) != nil)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.path)
            precondition(UpdatePolicy.installationError(at: app, osMajor: osMajor) == nil)
            try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
            precondition(UpdatePolicy.installationError(at: app, osMajor: osMajor) != nil)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        }
        precondition(fm.fileExists(atPath: app.path))
        print("PASS: stable version/build selection, trusted URLs, package rejection, OS/ownership/writability gates, and permission recovery.")
    }
}
