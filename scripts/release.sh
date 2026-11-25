#!/usr/bin/env bash
# Makes a notarized the DMG that opens without warnings on other Macs.
# One-time setup: xcrun notarytool store-credentials wispr-local
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/name.sh

PROFILE="${NOTARY_PROFILE:-wispr-local}"
DMG="dist/$APP_NAME.dmg"
identity="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')"
if [ "${SKIP_NOTARIZE:-}" != 1 ] && [ -z "$identity" ]; then
  echo "Notarizing needs a Developer ID Application certificate. SKIP_NOTARIZE=1 builds without it." >&2
  exit 1
fi
[ "${SKIP_NOTARIZE:-}" = 1 ] || export TIMESTAMP=1
./scripts/build-app.sh
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "dist/$APP_NAME.app" "$stage/$APP_NAME.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -ov -volname "$APP_NAME" -srcfolder "$stage" -format UDZO "$DMG"
if [ "${SKIP_NOTARIZE:-}" = 1 ]; then echo "Built $DMG (not notarized)"; exit 0; fi
codesign --force --timestamp --sign "$identity" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
echo "Built $DMG"
