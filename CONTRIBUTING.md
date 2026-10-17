# Contributing to MyStat

Pull requests are welcome, including small fixes and first contributions. Help keep MyStat fast, free, native, and lightweight.

## Workflow

1. Fork the repo and create a topic branch.
2. Build with `./scripts/build.sh` and run `./scripts/test.sh` on a Mac.
3. Check the menu bar, dropdown dismissal, and any readings affected by your change.
4. Open a pull request targeting `main`. Describe the problem, change, validation, and any hardware/OS limits.

**Every change goes through a PR, including maintainer changes.** Do not push application changes directly to `main`. The initial empty bootstrap commit exists only to give the first implementation PR a base.

Starting with the release after 0.2.1, macOS 27 on Apple Silicon is the primary target; qualify releases on both macOS 27 and macOS 26, retaining macOS 26 support until macOS 28 is released. A hardware smoke check passed on an M5 Pro running macOS 27.0.1, and successful operation was reported on an M5 MacBook Air running macOS 26; see the [evidence and limits](docs/testing/2026-10-12-hardware.md). macOS 27 sensor mappings remain experimental. Reports and PRs for new hardware are welcome, with actual measurements and clearly stated limitations.

Favor system frameworks and small, bounded background work. Sparkle is the approved bundled dependency for signed updates, with networking only for manual checks or explicitly opted-in scheduled checks and user-approved downloads. Do not add other runtime dependencies, network traffic, telemetry, subprocess polling, or privileged helpers. Automatic checks must remain off by default. Missing sensor data must stay unavailable rather than becoming a plausible-looking zero.

Run `./scripts/test-updates-integration.sh` for updater changes; it uses disposable apps, ephemeral signing keys, and a localhost server. Follow [release testing](docs/RELEASE_TESTING.md) in a clean macOS VM before each release, and preserve host hardware validation for sensors. Add focused tests when behavior warrants them. Hardware tests cannot prove physical sensor accuracy; include manual checks for sensor changes. For UI changes, attach screenshots containing only the app.

## Privacy and AI assistance

Use your GitHub-provided noreply address if you do not want a personal email published in commits. Never include credentials, machine-specific paths, raw diagnostics, or unrelated desktop content. Keep generated files in ignored `build/` or `dist/` directories.

AI-assisted contributions are welcome. Review and test them, mention material AI assistance in your PR, and take responsibility for what you submit. Do not submit code or assets without compatible licensing.

Contributions are licensed under the repository's MIT license. Preserve third-party notices.
