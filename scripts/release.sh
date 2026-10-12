#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/test.sh
# Always build a release binary, even if the caller enabled UI review mode.
UI_REVIEW=0 ./scripts/build.sh
codesign --verify --deep --strict build/MyStat.app
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
NAME="MyStat-${VERSION}-macos-arm64"
mkdir -p dist
STAGE=$(mktemp -d "$PWD/build/release.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
# Use only known deliverables; never archive the whole build directory.
ditto build/MyStat.app "$STAGE/MyStat.app"
cp LICENSE THIRD_PARTY_NOTICES.md INSTALL.md README.md "$STAGE/"
mkdir -p "$STAGE/docs/screenshots" "$STAGE/ThirdParty"
cp ThirdParty/Sparkle-LICENSE.txt "$STAGE/ThirdParty/"
cp docs/UPDATES.md docs/RELEASE_TESTING.md "$STAGE/docs/"
cp docs/screenshots/*.png "$STAGE/docs/screenshots/"
cp CONTRIBUTING.md "$STAGE/"
COPYFILE_DISABLE=1 ditto -c -k --norsrc "$STAGE" "dist/$NAME.zip"
(cd dist && shasum -a 256 "$NAME.zip" > SHA256SUMS)
printf 'Release: %s/dist/%s.zip\n' "$PWD" "$NAME"
