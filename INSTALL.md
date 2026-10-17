# Install MyStat

MyStat 0.2.2 is built for **Apple Silicon**, with **macOS 27 as the primary target** and macOS 26 support retained until macOS 28 is released. Actual-app UI checks passed on macOS 27.0.1 and 26.6, and a one-hour memory soak passed on an M5 Pro running macOS 27.0.1. See the [current results](docs/testing/2026-10-17-core-graphics-charts.md) and [hardware evidence and limits](docs/testing/2026-10-12-hardware.md). macOS 27 power-sensor mappings remain experimental; UI and memory testing do not establish independent sensor accuracy. This release does not include an Intel binary.

## Download and open

1. Download the `MyStat-<version>-macos-arm64.zip` asset from the [latest GitHub release](https://github.com/ballardcm/mystat/releases/latest).
2. Double-click the ZIP, then drag `MyStat.app` into an Applications folder you own, such as `~/Applications`.
3. Open MyStat. Its CPU / MEM / GPU display appears in your menu bar; it has no Dock icon.
4. Click the display to see details. MEM is **memory pressure**; the dropdown also shows the percentage of physical memory used.
5. Optional: use the dropdown's gear menu to enable **Launch at login** after placing the app in its permanent location.

Official releases starting with **0.2.0 are Developer ID signed and notarized by Apple**, with the notarization ticket included in the app. Open the downloaded app normally; no Open Anyway override is required. macOS may ask you to confirm opening an app downloaded from the internet.

Older 0.1.x releases and default local builds use ad-hoc signatures. For those builds only, if you trust the source, follow [Apple's per-app approval instructions](https://support.apple.com/en-us/102445). Never disable Gatekeeper globally. Building locally from source is another option.

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
