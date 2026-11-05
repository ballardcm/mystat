# Sourced by build/test/release scripts. Download only at build time; never at app launch.
SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
SPARKLE_DIR="$PWD/build/Sparkle-$SPARKLE_VERSION"
SPARKLE_ARCHIVE="$PWD/build/sparkle-download/Sparkle-$SPARKLE_VERSION.tar.xz"
mkdir -p "${SPARKLE_ARCHIVE:h}"
if [[ ! -f "$SPARKLE_ARCHIVE" ]]; then
    curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
        "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
        -o "$SPARKLE_ARCHIVE.download"
    mv "$SPARKLE_ARCHIVE.download" "$SPARKLE_ARCHIVE"
fi
if [[ "$(shasum -a 256 "$SPARKLE_ARCHIVE" | cut -d ' ' -f 1)" != "$SPARKLE_SHA256" ]]; then
    print -u2 "Sparkle archive checksum mismatch. Remove $SPARKLE_ARCHIVE and retry."
    exit 1
fi
mkdir -p "$SPARKLE_DIR"
tar -xf "$SPARKLE_ARCHIVE" -C "$SPARKLE_DIR" ./Sparkle.framework ./bin ./LICENSE
