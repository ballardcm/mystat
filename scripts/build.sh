#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build/module-cache build/MyStat.app/Contents/{MacOS,Resources}
source scripts/toolchain.sh
source scripts/sparkle.sh
xcrun clang -arch arm64 -ffile-prefix-map="$PWD"=. -O2 -Wall -Wextra -isysroot "$SDK" -mmacosx-version-min=14.0 -c Sources/Hardware/Hardware.c -o build/Hardware.o
xcrun clang -arch arm64 -ffile-prefix-map="$PWD"=. -O2 -Wall -Wextra -isysroot "$SDK" -mmacosx-version-min=14.0 -c Sources/Hardware/CLPC.c -o build/CLPC.o
SWIFT_FLAGS=()
if [[ "${UI_REVIEW:-0}" == "1" ]]; then SWIFT_FLAGS+=(-DUI_REVIEW); fi
xcrun swiftc "${SWIFT_FLAGS[@]}" -O -file-prefix-map "$PWD=." -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx14.0 -module-cache-path build/module-cache -import-objc-header Sources/Hardware/Hardware.h Sources/MyStat/*.swift build/Hardware.o build/CLPC.o -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -o build/MyStat.app/Contents/MacOS/MyStat.next
mv -f build/MyStat.app/Contents/MacOS/MyStat.next build/MyStat.app/Contents/MacOS/MyStat
cp LICENSE THIRD_PARTY_NOTICES.md build/MyStat.app/Contents/Resources/
mkdir -p build/MyStat.app/Contents/Frameworks
# Copy a fresh framework so removed upstream files cannot survive a rebuild.
rm -rf build/MyStat.app/Contents/Frameworks/Sparkle.framework
ditto "$SPARKLE_DIR/Sparkle.framework" build/MyStat.app/Contents/Frameworks/Sparkle.framework
# This app is not sandboxed and does not use Sparkle's optional XPC services.
rm -rf build/MyStat.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices
cp "$SPARKLE_DIR/LICENSE" build/MyStat.app/Contents/Resources/Sparkle-LICENSE.txt
codesign --force --sign - build/MyStat.app/Contents/Frameworks/Sparkle.framework
cp Resources/Info.plist build/MyStat.app/Contents/Info.plist
codesign --force --sign - build/MyStat.app
printf 'Built %s/build/MyStat.app\n' "$PWD"
