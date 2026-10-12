# Install MyStat

MyStat is built for and tested on **Apple Silicon running macOS 26**, with M5 Pro hardware testing and a reported successful test on an M5 MacBook Air. Version 0.1.3 also passed a hardware smoke check on an M5 Pro running macOS 27.0.1 and enables in-app updates on macOS 27; sensor accuracy there remains experimental. See the [hardware test results and limits](docs/testing/2026-10-12-hardware.md). This release does not include an Intel binary.

## Download and open

1. Download the `MyStat-<version>-macos-arm64.zip` asset from the [latest GitHub release](https://github.com/ballardcm/mystat/releases/latest).
2. Double-click the ZIP, then drag `MyStat.app` into an Applications folder you own, such as `~/Applications`.
3. Open MyStat. Its CPU / MEM / GPU display appears in your menu bar; it has no Dock icon.
4. Click the display to see details. MEM is **memory pressure**; the dropdown also shows the percentage of physical memory used.
5. Optional: use the dropdown's gear menu to enable **Launch at login** after placing the app in its permanent location.

The release has an ad-hoc code signature. It is **not Developer ID signed or notarized**, so macOS may block it on first launch. If you have reviewed the project and trust this download, first try opening the app, then use **System Settings → Privacy & Security → Open Anyway** for MyStat. Follow [Apple's instructions](https://support.apple.com/en-us/102445). No system-wide security changes are needed. Building locally from source is another option.

## Verify the download

Download `SHA256SUMS` from the same release and place it beside the ZIP. In Terminal, change to that folder and run:

```sh
shasum -a 256 -c SHA256SUMS
```

The result should show your downloaded ZIP's filename followed by `OK`. A checksum detects mismatched or corrupted downloads; it is not a substitute for trusting the release source.

## Update

For the published 0.1.1 release, quit MyStat, replace the app in Applications with 0.1.2 or later, then reopen it. This one-time manual upgrade is required to obtain the updater.

Updater-enabled builds offer **Check for Updates…** in the right-click and gear menus. You can optionally enable **Automatically check for updates** in the gear menu; it is off by default and checks about once per day. Review the version and release notes, then install and relaunch, defer, or skip. Downloads begin only after choosing Install; installation preserves preferences and the app's location.

Checks and downloads contact GitHub and its download CDN; system profiling and telemetry are disabled. Both the feed and downloaded archive must have valid signatures. If offline, verification fails, or the installation is not user-owned and writable, keep using the installed version or update manually. Move the app out of the downloaded ZIP/disk image into an Applications folder you own before using in-app updates. Updates do not require administrator authorization or a privileged helper. In-app updates accept macOS 26 and 27. An older MyStat installation on macOS 27 needs one manual installation of 0.1.3 because its existing updater blocks that OS. On macOS 26, MyStat 0.1.2 can install 0.1.3 through Check for Updates.

After an update has been downloaded and prepared, Sparkle may install it when you quit even if you defer the relaunch. Turning off automatic checks stops future scheduled checks; it does not cancel an update already in progress. Use Cancel/Skip in the updater to abandon that update.

The signed update feed offers the latest compatible stable release. If you already have it, a manual check reports that MyStat is up to date.

## Uninstall

Turn off **Launch at login** if enabled, quit MyStat, and move the app to Trash. There are no privileged helpers, launch daemons, or installed extensions. The app stores sampling and update preferences in macOS user defaults under `io.github.ballardcm.MyStat`; if desired, remove those preferences after quitting:

```sh
defaults delete io.github.ballardcm.MyStat
```

## Build instead

See the [README build instructions](README.md#build-from-source). The only development prerequisite is a compatible Apple Command Line Tools or Xcode installation.
