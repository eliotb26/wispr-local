#!/usr/bin/env bash
# Builds the app and installs it in /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/name.sh

APP="/Applications/$APP_NAME.app"
./scripts/build-app.sh
pkill -x wispr-local && sleep 2 || true
# The app used to have another name; two copies would both listen to the key.
OLD="/Applications/Wispr Local.app"
if [ "$(defaults read "$OLD/Contents/Info" CFBundleIdentifier 2>/dev/null)" = com.github.eliotb26.wispr-local ]; then rm -rf "$OLD"; fi
ditto "dist/$APP_NAME.app" "$APP.new"
rm -rf "$APP"
mv "$APP.new" "$APP"

# Reuse models and timings from the repo, if they're here, instead of downloading again.
support="$HOME/Library/Application Support/wispr-local"
mkdir -p "$support/models"
for model in models/ggml-large-v3-turbo-q5_0.bin models/ggml-silero-v5.1.2.bin; do
  target="$support/models/$(basename "$model")"
  if [ -f "$model" ] && [ ! -f "$target" ]; then cp "$model" "$target.part" && mv "$target.part" "$target"; fi
done
if [ -f runs.csv ] && [ ! -f "$support/runs.csv" ]; then cp runs.csv "$support/"; fi
echo "Installed $APP"
