# Repository instructions

- All changes go through a pull request to `main`. Never push code directly to `main` or bypass branch protection. The sole bootstrap commit is empty.
- Never publish the owner's real email. Use `3799765+ballardcm@users.noreply.github.com` for owner-authored Git commits and tags. Audit author and committer emails before every push.
- Keep the app native, lightweight, free, and without network requests, telemetry, runtime dependencies, or privileged helpers.
- macOS 26 is the built-and-tested target. macOS 27 support is future work; do not present experimental mappings as validated compatibility.
- Preserve the MIT license and third-party attribution. Disclose substantial AI assistance.
- Review `.gitignore` and staged files before publishing. Never commit `build/`, `dist/`, raw diagnostics, credentials, or screenshots of unrelated apps.
- Run appropriate build/tests. Sensor compatibility requires hardware validation in addition to unit tests.
