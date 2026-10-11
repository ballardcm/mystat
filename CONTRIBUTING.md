# Contributing to MyStat

Pull requests are welcome, including small fixes and first contributions. Help keep MyStat fast, free, native, and lightweight.

## Workflow

1. Fork the repo and create a topic branch.
2. Build with `./scripts/build.sh` and run `./scripts/test.sh` on a Mac.
3. Check the menu bar, dropdown dismissal, and any readings affected by your change.
4. Open a pull request targeting `main`. Describe the problem, change, validation, and any hardware/OS limits.

**Every change goes through a PR, including maintainer changes.** Do not push application changes directly to `main`. The initial empty bootstrap commit exists only to give the first implementation PR a base.

macOS 26 on Apple Silicon is the current target. macOS 27 support will be updated later; experimental mappings do not establish support. Reports and PRs for new hardware are welcome, with actual measurements and clearly stated limitations.

Favor system frameworks and small, bounded background work. Avoid adding runtime dependencies, networking, telemetry, subprocess polling, or privileged helpers without discussing the need first. Missing sensor data must stay unavailable rather than becoming a plausible-looking zero.

Add focused tests when behavior warrants them. Hardware tests cannot prove physical sensor accuracy; include manual checks for sensor changes. For UI changes, attach screenshots containing only the app.

## Privacy and AI assistance

Use your GitHub-provided noreply address if you do not want a personal email published in commits. Never include credentials, machine-specific paths, raw diagnostics, or unrelated desktop content. Keep generated files in ignored `build/` or `dist/` directories.

AI-assisted contributions are welcome. Review and test them, mention material AI assistance in your PR, and take responsibility for what you submit. Do not submit code or assets without compatible licensing.

Contributions are licensed under the repository's MIT license. Preserve third-party notices.
