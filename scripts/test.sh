#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
mkdir -p build
xcrun clang -Wall -Wextra -Werror -isysroot "$SDK" -I Sources/Hardware Tests/HardwareTests.c Sources/Hardware/Hardware.c Sources/Hardware/CLPC.c -framework IOKit -framework CoreFoundation -o build/hardware-tests
build/hardware-tests
