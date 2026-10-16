# flowfree

Hold a key, talk, let go. Clean text lands in whatever field you're typing in, in any app.

Speech-to-text runs locally with whisper.cpp. An optional Claude Haiku pass removes filler words, applies self-corrections ("Tuesday, no wait, Thursday") and spells names the way they already appear on screen. It costs $0 and uses about 300 lines of Swift.

## Run it

```sh
cd ~/Developer/wispr-local && swift run -c release flowfree
```

From inside Claude Code, put `!` in front:

```
! cd ~/Developer/wispr-local && swift run -c release flowfree
```

Once it prints `ready`, hold **right Option**, talk, and let go. You'll hear a *tink* when recording starts and a *pop* when it stops. Press `Ctrl+C` to quit.

| Flag | What it does |
|---|---|
| *(none)* | Whisper, then Claude cleanup |
| `--raw` | Whisper only. Faster, keeps filler words |
| `--lang auto` | Detect the spoken language (default `en`) |

## First-time setup

1. **Install whisper.cpp:**
   ```sh
   brew install whisper-cpp
   ```
2. **Download the speech model** (574 MB). It goes in `models/`, which git ignores:
   ```sh
   mkdir -p models && curl -L -o models/ggml-large-v3-turbo-q5_0.bin \
     https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
   ```
3. **Make sure the Claude Code CLI is signed in.** `claude` must be on your `PATH`. Cleanup runs through your existing plan, so no API key is needed.
4. **Grant permissions to your terminal app** (Terminal, Ghostty, iTerm…) in System Settings → Privacy & Security:
   - **Microphone**, to record your voice
   - **Accessibility**, for the global hotkey, reading the focused field and pasting

   Restart flowfree after granting them.

The very first dictation takes about 12 seconds while whisper compiles its GPU shaders. After that it's fast.

## How it works

```
right ⌥ down ─► capture context (frontmost app + focused field text, via Accessibility)
             └► record mic → 16 kHz mono WAV
right ⌥ up   ─► whisper-cli (local, Metal GPU)
             ─► claude -p --model haiku  (cleanup, uses screen context; skipped under 5 words)
             ─► save clipboard → put text (concealed type) → ⌘V → restore clipboard after 500 ms
```

| File | Job |
|---|---|
| `Sources/flowfree/main.swift` | Hotkey, pipeline orchestration, timing log |
| `Sources/flowfree/Recorder.swift` | Microphone to 16 kHz WAV |
| `Sources/flowfree/Context.swift` | Frontmost app and focused-field text |
| `Sources/flowfree/Pipeline.swift` | whisper.cpp and the Claude cleanup prompt |
| `Sources/flowfree/Paster.swift` | Clipboard swap, ⌘V, restore |
| `Sources/flowfree/Shell.swift` | Process runner with timeouts |

## Speed (M4 Pro)

| Step | Time |
|---|---|
| Transcription, warm | ~0.9 s |
| Cleanup via Claude Code CLI | 2–5 s (mostly CLI startup) |

Every dictation appends its timings (audio length, word count, asr/llm/total ms, app name) to `runs.csv`. **The text is never logged.**

## Privacy

Audio and transcription stay on your Mac. With cleanup on, the transcript, the frontmost app's name and up to 1,500 characters of the focused field go to Claude. Use `--raw` to keep everything local.

## Known gaps

- Cleanup latency: the Claude Code CLI starts fresh on every call. A direct API call or a local model would be around 1 s.
- Hold-to-talk only, with no hands-free toggle and no menu bar UI yet.
- Paste uses ⌘V, so fields that block paste won't receive the text.
- Requires the Accessibility grant on the terminal running it, not on a standalone app bundle.
