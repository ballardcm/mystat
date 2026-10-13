# Repository instructions

- All changes go through a pull request to `main`. Never push code directly to `main` or bypass branch protection. The sole bootstrap commit is empty.
- Never publish the owner's real email. Use `3799765+ballardcm@users.noreply.github.com` for owner-authored Git commits and tags. Audit author and committer emails before every push.
- Keep the app native, lightweight, free, and without telemetry or privileged helpers. The approved exception is bundled Sparkle for user-initiated or explicitly opted-in update traffic; keep automatic checks off by default and do not add other network requests or runtime dependencies.
- macOS 26 is the built-and-tested target. macOS 27 support is future work; do not present experimental mappings as validated compatibility.
- Preserve the MIT license and third-party attribution. Disclose substantial AI assistance.
- Review `.gitignore` and staged files before publishing. Never commit `build/`, `dist/`, raw diagnostics, credentials, or screenshots of unrelated apps.
- Run appropriate build/tests. Sensor compatibility requires hardware validation in addition to unit tests.
- Before Developer ID signing or notarization, build an ad-hoc candidate and visually test the actual app on macOS 26 at normal and small display sizes, including resizing while the dropdown is open. Check menu-bar alignment across digit changes, pause, and unavailable states; check the entire panel, dismissal, light/dark appearance, and settings. Record the exact source revision and observed results. Unit tests and rendered fixtures do not replace this pass. Any later UI change requires repeating the affected visual checks before signing.
