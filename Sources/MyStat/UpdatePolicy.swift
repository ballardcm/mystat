import Foundation
import Sparkle

/// App-specific restrictions in addition to Sparkle's signature, version and OS checks.
enum UpdatePolicy {
    static let feedURL = "https://raw.githubusercontent.com/ballardcm/mystat/main/docs/appcast.xml"
    static let releasesURL = URL(string: "https://github.com/ballardcm/mystat/releases")!

    static func accepts(version: String, build: String, currentVersion: String, currentBuild: String,
                        downloadURL: URL?, installationType: String, channel: String?) -> Bool {
        let stablePattern = #"^[0-9]+\.[0-9]+\.[0-9]+$"#
        guard version.range(of: stablePattern, options: .regularExpression) != nil,
              currentVersion.range(of: stablePattern, options: .regularExpression) != nil,
              build.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              currentBuild.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              SUStandardVersionComparator.default.compareVersion(version, toVersion: currentVersion) == .orderedDescending,
              SUStandardVersionComparator.default.compareVersion(build, toVersion: currentBuild) == .orderedDescending,
              channel == nil, installationType == "application",
              let url = downloadURL, url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
              url.path == "/ballardcm/mystat/releases/download/v\(version)/MyStat-\(version)-macos-arm64.zip"
        else { return false }
        return true
    }

    static func installationError(at bundleURL: URL, osMajor: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String? {
        guard osMajor == 26 else { return "In-app updates are supported on macOS 26. Download a compatible release manually." }
        let fm = FileManager.default
        // Sparkle otherwise offers administrator authorization for protected or differently owned installs.
        // Restrict updates to this user's own, writable, non-translocated app and parent directory.
        guard geteuid() != 0, bundleURL.pathExtension == "app",
              !bundleURL.path.contains("/AppTranslocation/"),
              bundleURL.standardizedFileURL == bundleURL.resolvingSymlinksInPath(),
              let attrs = try? fm.attributesOfItem(atPath: bundleURL.path),
              (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == geteuid(),
              (attrs[.groupOwnerAccountID] as? NSNumber)?.uint32Value == getegid(),
              fm.isWritableFile(atPath: bundleURL.path),
              fm.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
        else { return "Move MyStat to an Applications folder you own and can write to, or update it manually. MyStat does not request administrator access for updates." }
        return nil
    }
}
