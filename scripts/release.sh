#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
MODE="${1:---notarize}"
if (( $# > 1 )) || [[ "$MODE" != --notarize && "$MODE" != --adhoc && "$MODE" != --package-notarized ]]; then
    print -u2 'Usage: release.sh [--notarize | --adhoc | --package-notarized]'
    exit 1
fi
OUTPUT="$PWD/dist"
if [[ "$MODE" == --adhoc ]]; then
    export MYSTAT_SIGN_IDENTITY=-
    OUTPUT="$OUTPUT/adhoc"
elif [[ "$MODE" == --notarize ]]; then
    : "${MYSTAT_SIGN_IDENTITY:?Set a Developer ID Application identity (see docs/SIGNING.md)}"
    : "${MYSTAT_NOTARY_PROFILE:?Set a notarytool Keychain profile (see docs/SIGNING.md)}"
    if [[ "$MYSTAT_SIGN_IDENTITY" == - ]]; then
        print -u2 'A Developer ID Application identity is required for notarization.'
        exit 1
    fi
fi
if [[ "$MODE" != --package-notarized ]]; then
    ./scripts/test.sh
    # Always build a release binary, even if the caller enabled UI review mode.
    UI_REVIEW=0 ./scripts/build.sh
fi
codesign --verify --deep --strict build/MyStat.app
if [[ "$MODE" == --notarize ]]; then
    # Keep the submission and result for diagnosis/resumption, outside Git.
    SUBMISSION=$(mktemp -d "$PWD/build/notary.XXXXXX")
    ditto -c -k --keepParent build/MyStat.app "$SUBMISSION/MyStat.zip"
    print "Notarization evidence: $SUBMISSION"
    xcrun notarytool submit "$SUBMISSION/MyStat.zip" \
        --keychain-profile "$MYSTAT_NOTARY_PROFILE" --wait --timeout 30m \
        --output-format json > "$SUBMISSION/result.json"
    python3 - "$SUBMISSION/result.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Notarization:', result.get('id'), result.get('status'))
if result.get('status') != 'Accepted':
    sys.exit('Notarization was not accepted. See docs/SIGNING.md; no release was packaged.')
PY
    xcrun stapler staple build/MyStat.app
fi
if [[ "$MODE" != --adhoc ]]; then
    codesign --verify --deep --strict --test-requirement='anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' build/MyStat.app
    xcrun stapler validate build/MyStat.app
    spctl --assess --type execute --verbose=2 build/MyStat.app
fi
python3 - <<'PY'
import plistlib
with open('Resources/Info.plist', 'rb') as f:
    source = plistlib.load(f)
with open('build/MyStat.app/Contents/Info.plist', 'rb') as f:
    built = plistlib.load(f)
if source != built:
    raise SystemExit('Built app metadata does not match source. Rebuild before packaging.')
PY
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
NAME="MyStat-${VERSION}-macos-arm64"
mkdir -p "$OUTPUT"
STAGE=$(mktemp -d "$PWD/build/release.XXXXXX")
ARCHIVE=$(mktemp -d "$PWD/build/archive.XXXXXX")
trap 'rm -rf "$STAGE" "$ARCHIVE"' EXIT
# Use only known deliverables; never archive the whole build directory.
ditto build/MyStat.app "$STAGE/MyStat.app"
cp LICENSE THIRD_PARTY_NOTICES.md INSTALL.md README.md "$STAGE/"
mkdir -p "$STAGE/docs/screenshots" "$STAGE/ThirdParty"
cp ThirdParty/Sparkle-LICENSE.txt "$STAGE/ThirdParty/"
cp docs/UPDATES.md docs/RELEASE_TESTING.md docs/SIGNING.md "$STAGE/docs/"
cp docs/screenshots/*.png "$STAGE/docs/screenshots/"
cp CONTRIBUTING.md "$STAGE/"
COPYFILE_DISABLE=1 ditto -c -k --norsrc "$STAGE" "$ARCHIVE/$NAME.zip"
# Verify the deliverable after extraction, including preservation of the ticket.
ditto -x -k "$ARCHIVE/$NAME.zip" "$ARCHIVE/extracted"
codesign --verify --deep --strict "$ARCHIVE/extracted/MyStat.app"
if [[ "$MODE" != --adhoc ]]; then
    xcrun stapler validate "$ARCHIVE/extracted/MyStat.app"
    spctl --assess --type execute --verbose=2 "$ARCHIVE/extracted/MyStat.app"
fi
mv "$ARCHIVE/$NAME.zip" "$OUTPUT/$NAME.zip"
(cd "$OUTPUT" && shasum -a 256 "$NAME.zip" > SHA256SUMS)
printf 'Archive: %s/%s.zip\n' "$OUTPUT" "$NAME"
