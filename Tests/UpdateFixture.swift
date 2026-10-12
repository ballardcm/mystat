import AppKit
import CryptoKit

if CommandLine.arguments.count == 2 {
    let key = Curve25519.Signing.PrivateKey()
    try key.rawRepresentation.base64EncodedString().write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
    print(key.publicKey.rawRepresentation.base64EncodedString())
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "interval") == nil { defaults.set(5, forKey: "interval") }
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    let marker = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("launched-" + version)
    try String(defaults.integer(forKey: "interval")).write(to: marker, atomically: true, encoding: .utf8)
    app.run()
}
