#!/usr/bin/env bash
# Builds self-contained whisper.cpp helpers into .build/helpers, so the app needs no Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=v1.9.5
OUT=.build/helpers
SRC=.build/whisper.cpp-$VERSION
if [ -x "$OUT/whisper-server" ] && [ "$(cat "$OUT/version" 2>/dev/null)" = "$VERSION" ]; then exit 0; fi

if command -v cmake >/dev/null; then cmake=(cmake)
elif command -v uvx >/dev/null; then cmake=(uvx cmake)
else echo "cmake is required: brew install cmake" >&2; exit 1; fi

if [ ! -d "$SRC" ]; then
  rm -rf "$SRC.part"
  git clone --quiet --depth 1 --branch "$VERSION" https://github.com/ggml-org/whisper.cpp "$SRC.part"
  mv "$SRC.part" "$SRC"
fi
"${cmake[@]}" -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DWHISPER_BUILD_TESTS=OFF \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_ARCHITECTURES=arm64
"${cmake[@]}" --build "$SRC/build" -j 8 --target whisper-server whisper-vad-speech-segments
mkdir -p "$OUT"
cp "$SRC/build/bin/whisper-server" "$SRC/build/bin/whisper-vad-speech-segments" "$OUT/"
cp "$SRC/LICENSE" "$OUT/whisper.cpp-LICENSE"
echo "$VERSION" > "$OUT/version"
