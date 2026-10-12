#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
source scripts/sparkle.sh
mkdir -p build/module-cache build/update-integration
xcrun swiftc -sdk "$SDK" -target arm64-apple-macosx14.0 -module-cache-path build/module-cache Tests/UpdateFixture.swift -o build/update-integration/Fixture
xcrun clang -fobjc-arc -Wno-protocol -isysroot "$SDK" -F "$SPARKLE_DIR" -framework Sparkle -framework AppKit -Wl,-rpath,@executable_path/../Frameworks Tests/UpdateIntegration.m -o build/update-integration/Harness
PYTHONDONTWRITEBYTECODE=1 python3 Tests/UpdateIntegration.py
