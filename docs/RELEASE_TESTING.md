# Release testing

Each release needs automated tests, a clean macOS 26 VM pass, an upgrade pass, and a host hardware check. A successful compile or unit test alone is not release qualification.

## Local Parallels lab

Use an Apple Silicon macOS 26 VM in Parallels Desktop. Recommended allocation: 4 virtual CPUs, 8 GB RAM, 64 GB disk, shared/NAT networking. Keep the VM and IPSW outside the repository, in the host's Parallels folder. Do not share the host home directory or sign into an Apple Account in the guest. Share only a dedicated test-artifact folder when needed; never copy production signing keys into the VM.

Finish Setup Assistant with a dedicated local test account, install Parallels Tools, and install Xcode Command Line Tools if running source-level tests in the guest. Shut down and preserve a clean baseline before installing MyStat. Use a fresh clone for each release; do not overwrite the baseline. Some Parallels/macOS configurations limit snapshots, so a powered-off full clone is the baseline mechanism unless snapshots are explicitly verified.

For the owner's dedicated disposable lab, configure automatic login and no password requirement after sleep or the screen saver. Keep these settings confined to the test guests. Use Parallels guest execution after installing Tools so routine test commands do not require interactive authentication. Verify a full guest restart reaches the desktop and a guest command runs unattended before marking a baseline ready. Initial account creation and any authentication needed to enable these settings must be completed before preserving the baseline; do not store passwords in the repository, scripts, command arguments, or logs.

Maintain a separate macOS 27 experimental baseline with the same unattended configuration. Verify the restore image is supported by the host before installation. A working VM does not establish MyStat compatibility: record macOS 27 results separately, and retain macOS 26 as the release qualification target. Starting with 0.1.3, in-app updates accept macOS 27. Test its update flow separately; physical sensor mappings there remain experimental. Older builds already on 27 require a manual installation of 0.1.3 before they can check for updates.

Keep both clean OS baselines after successful upgrade tests, shut down between test sessions. The macOS 26 VM preserves release coverage when the physical host runs macOS 27; the macOS 27 VM remains useful for repeatable clean-install, upgrade, settings-persistence, and failure-recovery checks. Reuse or recreate working clones for future releases, leaving the baselines intact. Continue using physical hardware for sensor checks.

Host home, cloud folders, application sharing, shared clipboard, and automatic volume sharing should be disabled for both baselines. Keep Apple Account sign-in out of these disposable guests. Record the exact guest OS build and verify all settings rather than assuming a clone or a new OS version preserves them.

## Before signing: qualify the actual UI

Do this **before the first Developer ID signature or Apple submission**, using an ad-hoc candidate in the disposable macOS 26 test VM. First build with `./scripts/release.sh --adhoc` and run `./scripts/test-updates-integration.sh`. Use the established per-app approval flow for this local test build; do not disable Gatekeeper globally. This development pass is separate from the later quarantined notarized-install check.

- Inspect the actual menu-bar display with one-, two-, and three-digit readings, pause, and unavailable values. Confirm caption/value alignment and stable neighboring icons. Use the live meter fixture to force states unavailable on the VM, alongside the actual app.
- Before inspecting each host or VM, match the installed executable's SHA-256 to the candidate, then relaunch and verify the running process path. Version/build labels alone are insufficient when multiple candidates share them. Record which candidate each VM is running.
- Open the dropdown at a normal desktop size and a smaller VM display (for example, 800 × 600). Resize the VM while it is open, close/reopen, and confirm that the full header/footer remain visible below the menu bar and above the Dock. Scrolling must reach every section without clipped controls.
- Check light/dark appearance, gear and right-click menus, pause/resume, sampling settings, Escape, close-button, and outside-click dismissal.
- Record the exact source revision (and any uncommitted candidate diff), OS/display sizes, observed results, and defects. Fix defects and repeat affected checks before signing. Unit tests, static screenshots, and notarization acceptance are not substitutes for this visual pass.

Only then continue with Developer ID signing, Apple submission, and the signed clean-install/upgrade checks below. Any later UI change returns to this pre-signing stage.

## Build and automated checks

Configure the signing identity and notarization Keychain profile as described in [SIGNING.md](SIGNING.md). Official archives require the complete Apple verification path. For development/CI without credentials, use `./scripts/release.sh --adhoc` and check `dist/adhoc/SHA256SUMS`; this does not qualify a release.

```sh
./scripts/release.sh
./scripts/test-updates-integration.sh
(cd dist && shasum -a 256 -c SHA256SUMS)
codesign --verify --deep --strict build/MyStat.app
xcrun stapler validate build/MyStat.app
spctl --assess --type execute --verbose=2 build/MyStat.app
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
7. Test a quarantined candidate under normal macOS protections, as well as a standard user's writable `~/Applications` installation. For 0.2.0 onward, require Developer ID/Gatekeeper acceptance and a valid stapled notarization ticket without an Open Anyway override. Record the 0.1.3 ad-hoc → Developer ID transition and launch-at-login continuity explicitly.

Version 0.1.1 has no updater: test its manual replacement with the first updater-enabled release separately.

## Release evidence

Record commit, tag/version/build, ZIP SHA-256, host/guest macOS build, Parallels version, baseline/clone name, tests run, pass/fail results, and unresolved issues. Keep raw diagnostics and local logs in ignored `build/` or outside the repository. Commit only reviewed app-only screenshots. Block release on failed integrity, recovery, relaunch, permission, or data-preservation checks.

On the physical Apple Silicon host, compare CPU/memory and available GPU/thermal/power readings with trusted system readings. A VM cannot validate AppleSMC or IOReport sensor compatibility. The [2026-10-12 M5 Pro smoke check](testing/2026-10-12-hardware.md) demonstrated live readings and CPU workload response on macOS 27.0.1; independent sensor-accuracy validation and sleep/wake testing remain outstanding. Successful update tests do not establish sensor accuracy.
