#!/bin/zsh
# Sign nested code inside-out; --deep is for verification, never signing.
set -euo pipefail
APP="${1:?Usage: sign-app.sh APP}"
IDENTITY="${MYSTAT_SIGN_IDENTITY:--}"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
FLAGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then
    FLAGS+=(--options runtime --timestamp)
fi
codesign "${FLAGS[@]}" "$FRAMEWORK/Versions/B/Autoupdate"
codesign "${FLAGS[@]}" "$FRAMEWORK/Versions/B/Updater.app"
codesign "${FLAGS[@]}" "$FRAMEWORK"
codesign "${FLAGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ "$IDENTITY" != "-" ]]; then
    # Reject development/distribution certificates that are not Developer ID.
    codesign --verify --strict --test-requirement='anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
fi
