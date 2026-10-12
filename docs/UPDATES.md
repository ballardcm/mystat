# Signed updates

MyStat uses Sparkle 2.10.0 for optional updates. A custom installer would add security-sensitive download, replacement, recovery, and relaunch code to this small project. Sparkle provides these mechanisms and native UI. The owner approved the bundled dependency and narrowly scoped update networking; other app activity remains offline.

## Policy

- Automatic checks are off by default, with no permission nag on second launch. Users can opt in to daily checks or check manually from either menu. Automatic downloads and silent installs are disabled.
- Both feed and archives require Ed25519 signatures anchored to `SUPublicEDKey`. Feed failures never expire into unsigned fallback. Archives are verified before extraction. HTTPS is required for the production feed and downloads; macOS security protections remain enabled.
- The production feed is fixed to this repository's `main/docs/appcast.xml`. Only newer stable numeric versions and increasing integer build numbers are accepted. Downloads must be the expected arm64 ZIP from the official release's `v<version>` tag. Package installers and alternate channels are rejected.
- The generated feed specifies macOS 26.0–26.99. The application also rejects in-app updates outside macOS 26. This is a support boundary, not a claim of macOS 27 compatibility.
- Before checking and again before accepting an update, MyStat rejects installations owned by another user/group, unwritable app/parent paths, root execution, symlinks, and translocated bundles. This avoids Sparkle's administrator-authorization path for protected installations. No privileged helper is installed. Sparkle uses temporary user-level installer/relaunch processes for writable installations. Permissions must remain unchanged during installation.
- Release notes are embedded plain text in the signed feed. JavaScript, external release-note downloads, system profiling, telemetry, and automatic installation are disabled. GitHub receives ordinary network metadata and a User-Agent; the app sends no sampled statistics or hardware profile.
- Turning off checks prevents future scheduled checks, not cancellation of an already authorized operation. After download/preparation, deferring relaunch may still install on quit. Users can cancel/skip in Sparkle's UI.

The initial signed feed intentionally contains no release entries. It is usable after the branch is merged, and can be populated once a compatible stable release is actually available. Existing 0.1.1 apps require one manual upgrade because they contain no updater or trusted update key.

## Keys and dependency

The production private Ed25519 key is stored in the maintainer's macOS Keychain under Sparkle's account `io.github.ballardcm.MyStat`. Only the public key is committed. Back up the key securely before shipping: use Sparkle's documented `generate_keys --account io.github.ballardcm.MyStat -x <secure-backup-file>` procedure and keep the result outside the repository. Losing this key can require a manual upgrade; feed-signature fallback is deliberately disabled. Do not generate a replacement key casually or publish a private export.

`scripts/sparkle.sh` pins the upstream archive and SHA-256. The first build downloads it; subsequent builds verify and reuse the cached archive. Framework, build tools, and full upstream licenses are extracted only into ignored `build/`. The app bundles the framework and license, removing unused sandbox XPC services. Update the pinned version, checksum, documentation, and signing-tool path together when upgrading Sparkle.

## Publishing a stable update

1. Increment `CFBundleShortVersionString` and `CFBundleVersion` in a PR. Both must increase relative to the prior stable release. Review notes and run the tests in [RELEASE_TESTING.md](RELEASE_TESTING.md).
2. Run `./scripts/release.sh`. The archive must be named `MyStat-<version>-macos-arm64.zip`. Current builds remain ad-hoc signed; Ed25519 authenticates updates but does not provide Apple Developer ID identity or notarization. Never remove quarantine or bypass Gatekeeper in the updater. If Developer ID signing/notarization is adopted, finish all signing and stapling before generating the archive and update signature.
3. Create a plain-text release notes file outside tracked source, then run:

   ```sh
   python3 scripts/create-appcast.py \
     --archive dist/MyStat-<version>-macos-arm64.zip \
     --notes build/release-notes.txt \
     --output build/appcast.xml
   ```

   The tool checks the archive's bundle identity, feed, public key, security settings, stable version, and filename. It checks the Keychain public key against the source, signs the archive and feed, and verifies the feed. It neither uploads files nor publishes a release. Re-sign after any modification to the feed or archive.
4. Publish the exact tested ZIP and checksum as a **stable**, non-draft GitHub release tagged `v<version>`. Audit commit/tag emails before pushing; use the owner's GitHub noreply address. Do not put prereleases in the stable feed.
5. Download and compare the published artifact's checksum. Copy `build/appcast.xml` to `docs/appcast.xml`, review it, and merge through a PR to `main` only after the release is available. The feed contains the latest stable release; older OS branches are not currently supported.
6. In a disposable VM clone running the previous updater-enabled release, confirm the production HTTPS feed offers the intended version, displays notes, installs/relaunches, preserves preferences and launch-at-login behavior, and stops offering the update afterwards. Archive the test result with the release review. Keep signing keys out of VMs.

Bootstrap only: `python3 scripts/create-appcast.py --empty --output build/appcast.xml` creates a signed empty feed. This is not a replacement for testing the first real update.

## Tests and limits

`./scripts/test.sh` covers app-specific selection, URL/OS/permission rules, recovery after permission changes, and feed generation/defaults. `./scripts/test-updates-integration.sh` drives the real Sparkle verifier/downloader/installer against disposable bundles, ephemeral test keys, and a localhost server. It checks old/same versions, beta/unsupported releases, defer/cancel, altered feed and archive signatures, missing downloads, install/relaunch, and preference retention. Test HTTP/ATS exceptions exist only in disposable test bundles; production stays HTTPS-only.

Integration tests do not prove Gatekeeper behavior for downloaded release artifacts, real launch-at-login continuity, or physical sensor accuracy. Those require the VM/manual and host-hardware checks in the release checklist.

References: [Sparkle setup](https://sparkle-project.org/documentation/), [security settings](https://sparkle-project.org/documentation/customization/), [publishing](https://sparkle-project.org/documentation/publishing/). Substantial implementation and test assistance: OpenAI Codex.
