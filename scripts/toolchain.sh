# Sourced by the zsh build/check scripts. Prefer the active toolchain's
# default SDK symlink over an inherited SDKROOT for a different compiler.
MYSTAT_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ -n "${MYSTAT_SDK:-}" ]]; then
    SDK="$MYSTAT_SDK"
elif [[ -d "$MYSTAT_DEVELOPER_DIR/SDKs/MacOSX.sdk" ]]; then
    SDK="$MYSTAT_DEVELOPER_DIR/SDKs/MacOSX.sdk"
else
    SDK="$MYSTAT_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
fi
if [[ ! -d "$SDK" ]]; then
    print -u2 "Compatible macOS SDK not found. Install Apple Command Line Tools or set MYSTAT_SDK."
    exit 1
fi
export SDKROOT="$SDK"
