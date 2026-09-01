#!/bin/sh

set -eu

VERSION="${1:-}"
case "$VERSION" in
  ""|*[!0-9A-Za-z.-]*)
    echo "usage: $0 <version>" >&2
    exit 2
    ;;
esac

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT="$PROJECT_ROOT/build"
DIST_ROOT="$PROJECT_ROOT/dist"
APP_PATH="$BUILD_ROOT/Softbreak.app"
ARCH=$(uname -m)
DMG_NAME="Softbreak-$VERSION-$ARCH.dmg"
DMG_PATH="$DIST_ROOT/$DMG_NAME"

"$PROJECT_ROOT/scripts/make-app.sh" release

mkdir -p "$DIST_ROOT"
STAGING_ROOT=$(mktemp -d "$BUILD_ROOT/.softbreak-dmg.XXXXXX")
trap 'rm -rf "$STAGING_ROOT"' EXIT INT TERM

cp -R "$APP_PATH" "$STAGING_ROOT/Softbreak.app"
ln -s /Applications "$STAGING_ROOT/Applications"

rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create \
  -volname "Softbreak $VERSION" \
  -srcfolder "$STAGING_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

(
  cd "$DIST_ROOT"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "$DMG_PATH"
