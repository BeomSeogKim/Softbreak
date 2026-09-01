#!/bin/sh

set -eu

CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT="$PROJECT_ROOT/build"
APP_PATH="$BUILD_ROOT/Softbreak.app"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "$PROJECT_ROOT"
swift build -c "$CONFIGURATION"
BIN_DIR=$(swift build -c "$CONFIGURATION" --show-bin-path)
mkdir -p "$BUILD_ROOT"
APP_TEMP=$(mktemp -d "$BUILD_ROOT/.softbreak.XXXXXX")
trap 'rm -rf "$APP_TEMP"' EXIT INT TERM

mkdir -p "$APP_TEMP/Contents/MacOS" "$APP_TEMP/Contents/Resources"
cp "$BIN_DIR/WritingApp" "$APP_TEMP/Contents/MacOS/Softbreak"
cp "$PROJECT_ROOT/Sources/WritingApp/Info.plist" "$APP_TEMP/Contents/Info.plist"
cp "$PROJECT_ROOT/Sources/WritingApp/Resources/document.css" "$APP_TEMP/Contents/Resources/document.css"

plutil -lint "$APP_TEMP/Contents/Info.plist" >/dev/null
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP_TEMP" >/dev/null
else
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_TEMP" >/dev/null
fi
codesign --verify --deep --strict "$APP_TEMP"
test -f "$APP_TEMP/Contents/Resources/document.css"

rm -rf "$APP_PATH"
mv "$APP_TEMP" "$APP_PATH"
trap - EXIT INT TERM

echo "$APP_PATH"
