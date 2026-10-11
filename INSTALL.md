# Install MyStat

MyStat is built for and tested on **Apple Silicon running macOS 26**. macOS 27 support is planned for a later update. This release does not include an Intel binary.

## Download and open

1. Download `MyStat-0.1.0-macos-arm64.zip` from the [GitHub release](https://github.com/ballardcm/mystat/releases/latest).
2. Double-click the ZIP, then drag `MyStat.app` into Applications.
3. Open MyStat. Its CPU / MEM / GPU display appears in your menu bar; it has no Dock icon.
4. Click the display to see details. MEM is **memory pressure**; the dropdown also shows the percentage of physical memory used.
5. Optional: use the dropdown's gear menu to enable **Launch at login** after placing the app in its permanent location.

The release has an ad-hoc code signature. It is **not Developer ID signed or notarized**, so macOS may block it on first launch. If you have reviewed the project and trust this download, first try opening the app, then use **System Settings → Privacy & Security → Open Anyway** for MyStat. Follow [Apple's instructions](https://support.apple.com/en-us/102445). No system-wide security changes are needed. Building locally from source is another option.

## Verify the download

Download `SHA256SUMS` from the same release and place it beside the ZIP. In Terminal, change to that folder and run:

```sh
shasum -a 256 -c SHA256SUMS
```

The result should be `MyStat-0.1.0-macos-arm64.zip: OK`. A checksum detects mismatched or corrupted downloads; it is not a substitute for trusting the release source.

## Update

Quit MyStat from its right-click menu or dropdown settings. Replace the app in Applications with the new version, then reopen it. MyStat does not download updates automatically.

## Uninstall

Turn off **Launch at login** if enabled, quit MyStat, and move the app to Trash. There are no privileged helpers, launch daemons, or installed extensions. The app stores its sampling preference in macOS user defaults under `io.github.ballardcm.MyStat`; if desired, remove those preferences after quitting:

```sh
defaults delete io.github.ballardcm.MyStat
```

## Build instead

See the [README build instructions](README.md#build-from-source). The only development prerequisite is a compatible Apple Command Line Tools or Xcode installation.
