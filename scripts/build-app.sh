#!/usr/bin/env bash
# Builds the app in dist/. Set TIMESTAMP=1 for a build that will be notarized.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/name.sh

APP="dist/$APP_NAME.app"
PLIST="$APP/Contents/Info.plist"
VERSION="${VERSION:-1.3}"

./scripts/build-helpers.sh
swift build -c release --arch arm64
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$(swift build -c release --arch arm64 --show-bin-path)/wispr-local" "$APP/Contents/MacOS/"
cp .build/helpers/whisper-server .build/helpers/whisper-vad-speech-segments "$APP/Contents/Helpers/"
cp .build/helpers/whisper.cpp-LICENSE "$APP/Contents/Resources/"

[ -f .build/AppIcon.icns ] && [ .build/AppIcon.icns -nt scripts/make-icon.swift ] || swift scripts/make-icon.swift .build/AppIcon.icns
cp .build/AppIcon.icns "$APP/Contents/Resources/"
ditto assets/fonts "$APP/Contents/Resources/Fonts"

plutil -create xml1 "$PLIST"
set_key() { plutil -insert "$1" "-$2" "$3" "$PLIST"; }
set_key CFBundleIdentifier string com.github.eliotb26.wispr-local
set_key CFBundleName string "$APP_NAME"
set_key CFBundleExecutable string wispr-local
set_key CFBundlePackageType string APPL
set_key CFBundleShortVersionString string "$VERSION"
set_key CFBundleVersion string "$VERSION"
set_key ATSApplicationFontsPath string Fonts
set_key CFBundleIconFile string AppIcon
set_key LSMinimumSystemVersion string 13.0
set_key LSUIElement bool true
set_key NSMicrophoneUsageDescription string "Records while you hold the key, then transcribes on this Mac."

# A stable signature keeps the macOS permissions across rebuilds; "-" is ad hoc.
identity="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')"
timestamp=--timestamp=none
[ "${TIMESTAMP:-}" = 1 ] && timestamp=--timestamp
sign() { codesign --force --options runtime "$timestamp" --sign "${identity:--}" "$@"; }
for helper in "$APP"/Contents/Helpers/*; do sign "$helper"; done
sign --entitlements scripts/app.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
