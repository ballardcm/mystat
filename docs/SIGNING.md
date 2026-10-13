# Developer ID signing and notarization

MyStat 0.2.0 introduces Developer ID signing and Apple notarization. Every official release must pass real signing, notarization, Gatekeeper, macOS 26 VM, and upgrade checks before publication. Ad-hoc CI artifacts are test builds only.

## One-time setup on the maintainer's Mac

1. Wait for the paid Apple Developer Program membership to become active. A signed-in Apple Account with a pending enrollment cannot issue the required certificate. Avoid purchasing again while Apple processes the existing payment.
2. Create a **Developer ID Application** certificate using the account's Certificates, Identifiers & Profiles page and a locally generated certificate signing request, or Xcode's certificate manager. Import the issued certificate into the same Mac's login Keychain, alongside its private key. A Developer ID Installer certificate is not needed for this ZIP distribution. Use the GitHub noreply address if a CSR asks for an email; never include a personal email in published files.
3. Check the identity with `security find-identity -v -p codesigning`. Keep the private key in Keychain and back it up securely outside the repository. Do not put production keys in CI or test VMs.
4. Create an app-specific password in the Apple Account website yourself, then run this command in your own Terminal:

   ```sh
   xcrun notarytool store-credentials MyStat-notary
   ```

   Answer its interactive prompts for the Apple Account, team ID, and app-specific password. The password is stored in Keychain. Do not paste it into chat, command arguments, source, or logs. An existing App Store Connect API key can also be used with notarytool; it is not required.

## Build the official archive

First qualify an **ad-hoc candidate visually on macOS 26**, following the [before-signing checklist](RELEASE_TESTING.md#before-signing-qualify-the-actual-ui). Check the real app at normal and small display sizes and during resizing; record the source revision and fix any defects before invoking the signing command. Then sign and qualify that candidate from the release branch before merging its PR. After merge, build the official artifact from the exact merged commit and verify that artifact before publishing. Use the certificate name or SHA-1 identity hash reported by `security find-identity`:

```sh
export MYSTAT_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
export MYSTAT_NOTARY_PROFILE=MyStat-notary
./scripts/release.sh
```

The script runs automated checks, builds, signs Sparkle's Autoupdate and Updater app, signs the framework, and finally signs MyStat. All distribution code uses the same identity, hardened runtime, and secure timestamps. No hardened-runtime exceptions or new app entitlements are added. The script verifies Developer ID signing, submits to Apple, requires an `Accepted` result, staples and validates the ticket, and checks Gatekeeper before packaging. Apple submission traffic is release tooling only; the app's existing update/network policy is unchanged.

The final `dist/MyStat-0.2.0-macos-arm64.zip` and `dist/SHA256SUMS` are created **after stapling**. Generate the Sparkle archive/feed signatures only from this final ZIP, using the existing production Ed25519 key. See [UPDATES.md](UPDATES.md) for the release-first, feed-second PR workflow. Do not rebuild, re-sign, re-staple, or edit an archive after signing it for Sparkle.

For local development, `./scripts/build.sh` still defaults to ad-hoc signing when `MYSTAT_SIGN_IDENTITY` is unset. CI explicitly runs `./scripts/release.sh --adhoc`; these archives are isolated in `dist/adhoc/` and must not be uploaded as official releases. CI does not require Apple credentials.

## Pending or rejected submissions

The release script prints an ignored `build/notary.*` evidence directory containing the submitted ZIP and JSON result. Apple can take longer than the script's 30-minute wait. A timeout does not cancel the submission. Use the submission ID reported by notarytool (or `notarytool history`) to check it without submitting another copy:

```sh
xcrun notarytool history --keychain-profile MyStat-notary
xcrun notarytool info SUBMISSION_ID --keychain-profile MyStat-notary
xcrun notarytool log SUBMISSION_ID --keychain-profile MyStat-notary build/notary-log.json
```

If it later becomes Accepted, and `build/MyStat.app` is still the exact submitted app, resume:

```sh
xcrun stapler staple build/MyStat.app
./scripts/release.sh --package-notarized
```

The resume command verifies the Developer ID signature, staple, Gatekeeper acceptance, and source/bundle metadata before packaging. It deliberately does not rebuild. If source or app contents have changed, rebuild and submit a new candidate. Never publish an earlier ZIP left in `dist/` after a failed run; match the final artifact checksum to the recorded release evidence.

## Release qualification

Verify the ZIP checksum, extract a fresh copy, and run `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess --type execute --verbose=2` on that copy. Record the signer/team, notarization submission ID and Accepted status, checksum, source commit, version/build, and test results. Inspect certificate metadata for accidental personal email disclosure before publishing.

Run the [release checklist](RELEASE_TESTING.md) on macOS 26, including a quarantined clean installation and the real 0.1.3 → 0.2.0 Sparkle upgrade. Check preference and launch-at-login continuity across the transition from ad-hoc to Developer ID signing. Keep macOS 27 results explicitly experimental and validate physical sensors separately. Do not merge the release preparation PR or publish an archive on the strength of mocked signing tests or ad-hoc CI alone. Once signing and notarization are verified, update the README and install guide's current ad-hoc release notice before building the final archive; retain any needed guidance for older releases and local builds.

References: [Apple Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/), [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [Sparkle manual code signing](https://sparkle-project.org/documentation/sandboxing/#code-signing). Prepared with substantial OpenAI Codex assistance.
