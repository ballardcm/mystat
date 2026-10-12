import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var canCheck = false
    var dismissDashboard: (() -> Void)?
    private var controller: SPUStandardUpdaterController!
    private var observations: [NSKeyValueObservation] = []
    private var startupError: Error?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.automaticallyChecks = updater.automaticallyChecksForUpdates }
            }
        ]
    }

    func start() {
        // Diagnostics and snapshots must never schedule network work, even for an opted-in user.
        guard !CommandLine.arguments.contains("--snapshot") else { return }
        do { try controller.updater.start() } catch { startupError = error; canCheck = true }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        if enabled, let error = UpdatePolicy.installationError(at: Bundle.main.bundleURL) {
            showError(error); return
        }
        if let startupError { showError(startupError.localizedDescription); return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        dismissDashboard?()
        if let startupError { showError(startupError.localizedDescription); return }
        if let error = UpdatePolicy.installationError(at: Bundle.main.bundleURL) { showError(error); return }
        guard canCheck else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    private func showError(_ message: String) {
        dismissDashboard?()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MyStat could not check for updates"
        alert.informativeText = message + "\n\nYou can download the latest release from GitHub and replace the app manually."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Releases")
        if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(UpdatePolicy.releasesURL) }
    }

    func feedURLString(for updater: SPUUpdater) -> String? { UpdatePolicy.feedURL }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { [] }
    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        if updateCheck != .updates && !updater.automaticallyChecksForUpdates {
            throw policyError("Automatic update checks are disabled.")
        }
        if let error = UpdatePolicy.installationError(at: Bundle.main.bundleURL) { throw policyError(error) }
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard UpdatePolicy.accepts(version: item.displayVersionString, build: item.versionString,
            currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            currentBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            downloadURL: item.fileURL, installationType: item.installationType, channel: item.channel) else {
            throw policyError("This release is not a newer, compatible stable MyStat update. Please check GitHub Releases.")
        }
        if let error = UpdatePolicy.installationError(at: Bundle.main.bundleURL) { throw policyError(error) }
    }

    // Notes are embedded as plain text in the authenticated feed, with no additional requests.
    func updater(_ updater: SPUUpdater, shouldDownloadReleaseNotesForUpdate item: SUAppcastItem) -> Bool { false }
    func standardUserDriverWillShowModalAlert() { dismissDashboard?() }
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if handleShowingUpdate { dismissDashboard?() }
    }

    private func policyError(_ message: String) -> NSError {
        NSError(domain: "io.github.ballardcm.MyStat.Updates", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
