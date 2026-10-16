#!/usr/bin/env bash
# One-time setup: installs whisper.cpp and downloads the speech model (574 MB).
set -euo pipefail

MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"
MODEL_PATH="models/ggml-large-v3-turbo-q5_0.bin"

cd "$(dirname "$0")/.."

if ! command -v brew >/dev/null; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi

if ! command -v whisper-cli >/dev/null; then
  echo "Installing whisper.cpp..."
  brew install whisper-cpp
fi

if [ ! -f "$MODEL_PATH" ]; then
  echo "Downloading the speech model (574 MB)..."
  mkdir -p models
  curl -L --fail --progress-bar -o "$MODEL_PATH.part" "$MODEL_URL"
  mv "$MODEL_PATH.part" "$MODEL_PATH"
fi

if ! command -v claude >/dev/null; then
  echo "Note: the Claude Code CLI isn't on your PATH. Cleanup will be skipped; use --raw or install it from https://claude.com/claude-code"
fi

echo "Building..."
swift build -c release

echo
echo "Done. Run it with:  swift run -c release wispr-local"
