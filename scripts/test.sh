#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
mkdir -p build
xcrun clang -Wall -Wextra -Werror -isysroot "$SDK" -I Sources/Hardware Tests/HardwareTests.c Sources/Hardware/Hardware.c Sources/Hardware/CLPC.c -framework IOKit -framework CoreFoundation -o build/hardware-tests
build/hardware-tests
source scripts/sparkle.sh
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx14.0 -module-cache-path build/module-cache -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE_DIR" Sources/MyStat/UpdatePolicy.swift Tests/UpdateTests.swift -o build/update-tests
build/update-tests
xcrun swiftc -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx14.0 -module-cache-path build/module-cache Sources/MyStat/MenuBarMeter.swift Tests/MenuBarMeterTests.swift -framework AppKit -o build/menu-bar-tests
build/menu-bar-tests
PYTHONDONTWRITEBYTECODE=1 python3 Tests/AppcastTests.py
PYTHONDONTWRITEBYTECODE=1 python3 Tests/ReleaseTests.py
