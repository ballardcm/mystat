# Release testing

Each release needs automated tests, a clean macOS 26 VM pass, an upgrade pass, and a host hardware check. A successful compile or unit test alone is not release qualification.

## Local Parallels lab

Use an Apple Silicon macOS 26 VM in Parallels Desktop. Recommended allocation: 4 virtual CPUs, 8 GB RAM, 64 GB disk, shared/NAT networking. Keep the VM and IPSW outside the repository, in the host's Parallels folder. Do not share the host home directory or sign into an Apple Account in the guest. Share only a dedicated test-artifact folder when needed; never copy production signing keys into the VM.

Finish Setup Assistant with a dedicated local test account, install Parallels Tools, and install Xcode Command Line Tools if running source-level tests in the guest. Shut down and preserve a clean baseline before installing MyStat. Use a fresh clone for each release; do not overwrite the baseline. Some Parallels/macOS configurations limit snapshots, so a powered-off full clone is the baseline mechanism unless snapshots are explicitly verified.

For the owner's dedicated disposable lab, configure automatic login and no password requirement after sleep or the screen saver. Keep these settings confined to the test guests. Use Parallels guest execution after installing Tools so routine test commands do not require interactive authentication. Verify a full guest restart reaches the desktop and a guest command runs unattended before marking a baseline ready. Initial account creation and any authentication needed to enable these settings must be completed before preserving the baseline; do not store passwords in the repository, scripts, command arguments, or logs.

Maintain a separate macOS 27 experimental baseline with the same unattended configuration. Verify the restore image is supported by the host before installation. A working VM does not establish MyStat compatibility: record macOS 27 results separately, and retain macOS 26 as the release qualification target. In-app updates currently reject macOS 27 by policy.

Host home, cloud folders, application sharing, shared clipboard, and automatic volume sharing should be disabled for both baselines. Keep Apple Account sign-in out of these disposable guests. Record the exact guest OS build and verify all settings rather than assuming a clone or a new OS version preserves them.

## Build and automated checks

```sh
./scripts/release.sh
./scripts/test-updates-integration.sh
(cd dist && shasum -a 256 -c SHA256SUMS)
codesign --verify --deep --strict build/MyStat.app
```

The integration suite runs an ephemeral localhost server and replaces/relaunches only uniquely identified disposable fixture apps. It does not install a MyStat release, change the real MyStat defaults, or use the production signing key. Run it on the host and in the test VM when tooling is available.

## Clean-install pass

Start from the clean baseline clone. Download the candidate using a browser so quarantine and normal Gatekeeper behavior are exercised. Verify the checksum, extract, move to an Applications folder owned by the test account, and open using the documented macOS per-app approval flow if required. Never disable Gatekeeper globally or remove quarantine to make a test pass.

Record:

- Version in the dropdown matches the archive and bundle metadata.
- Menu-bar display, dark/light appearance, compact layout, close button, Escape, outside-click dismissal, and gear/right-click menus work.
- Refresh interval, pause/resume, sleep/wake, quit/reopen, and unavailable sensor values behave correctly.
- Automatic update checks start off. Observe no update traffic before a manual check or opt-in, and verify opt-out persists across relaunch.
- Launch at login registers at the permanent app path and works after guest logout/login.
- Manual checks show current/no-update results, notes for newer stable releases, and useful offline/error feedback.

VMs do not expose all physical sensors. Unavailable GPU, temperature, fan, or power values must show a dash. Never describe VM sensor results as hardware compatibility validation.

## Upgrade pass

Use a separate clone with the previous updater-enabled release installed. Set a non-default sampling interval and enable launch at login. Test both manual and opted-in scheduled checks against the signed candidate feed; production releases must also pass against the actual HTTPS feed after publishing.

1. Confirm only the intended newer stable release appears with correct notes. Defer and skip; confirm no replacement occurs, and a manual check can offer a skipped release again.
2. Begin download and cancel. Interrupt connectivity and retry. The existing app must remain runnable.
3. Confirm modified feed/archive signatures are rejected, and old, equal, prerelease, or incompatible versions are not installed. Use disposable test keys/fixtures for destructive negative tests, never the production feed.
4. Install and relaunch. Verify the new dropdown version, exactly one running instance, preserved sampling settings, the original app path, and working launch at login after guest logout/login.
5. Check again: no further update offered. Turn off automatic checks and reopen: preference remains off.
6. Use a clone to test an unwritable or differently owned install; expect manual-update guidance before downloading, with no administrator prompt. Restore permissions and confirm checks work again.
7. Test a quarantined candidate under normal macOS protections, as well as a standard user's writable `~/Applications` installation. Record Gatekeeper/ad-hoc-signature behavior explicitly.

Version 0.1.1 has no updater: test its manual replacement with the first updater-enabled release separately.

## Release evidence

Record commit, tag/version/build, ZIP SHA-256, host/guest macOS build, Parallels version, baseline/clone name, tests run, pass/fail results, and unresolved issues. Keep raw diagnostics and local logs in ignored `build/` or outside the repository. Commit only reviewed app-only screenshots. Block release on failed integrity, recovery, relaunch, permission, or data-preservation checks.

On the physical Apple Silicon host, compare CPU/memory and available GPU/thermal/power readings with trusted system readings. A VM cannot validate AppleSMC or IOReport sensor compatibility. macOS 27 remains future work until separately validated.
