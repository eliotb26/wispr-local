#!/usr/bin/env python3
"""Compares speech models on your Voice Test recordings. Usage: scripts/voice-eval.py model.bin [model.bin ...]"""
import re
import subprocess
import sys
import time
from pathlib import Path

FOLDER = Path.home() / "Library/Application Support/wispr-local/voice-test"
NUMBERS = {"three": "3", "thirty": "30", "twenty": "20", "330": "3 30"}


def words(text: str) -> list[str]:
    text = text.lower().replace("’", "'").replace("%", " percent").replace(":", " ")
    tokens = [NUMBERS.get(word, word) for word in re.findall(r"[a-z0-9']+", text)]
    return " ".join(tokens).split()


def distance(expected: list[str], heard: list[str]) -> int:
    """Word-level edit distance."""
    row = list(range(len(heard) + 1))
    for i, want in enumerate(expected, 1):
        new = [i]
        for j, got in enumerate(heard, 1):
            new.append(min(row[j] + 1, new[j - 1] + 1, row[j - 1] + (want != got)))
        row = new
    return row[-1]


def transcribe(model: str, wav: Path) -> str:
    result = subprocess.run(["whisper-cli", "-m", model, "-f", str(wav), "-l", "en", "-nt", "-np"],
                            capture_output=True, text=True, check=True, timeout=120)
    return " ".join(result.stdout.split())


def main(models: list[str]) -> int:
    wavs = sorted(FOLDER.glob("*.wav"))
    if not models or not wavs:
        print(__doc__ if not models else f"No recordings in {FOLDER}. Use Voice Test in the app's menu first.")
        return 1
    for model in models:
        errors = total = 0
        started = time.time()
        misses = []
        for wav in wavs:
            expected = wav.with_suffix(".txt").read_text()
            heard = transcribe(model, wav)
            wrong = distance(words(expected), words(heard))
            errors, total = errors + wrong, total + len(words(expected))
            if wrong:
                misses.append(f"  said:  {expected}\n  heard: {heard}")
        seconds = (time.time() - started) / len(wavs)
        print(f"{Path(model).name}: {100 * errors / total:.1f}% of words wrong "
              f"({errors}/{total}, {len(wavs)} recordings, {seconds:.1f}s each, including model load)")
        print("\n\n".join(misses) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
