# wispr-local

**A free, local alternative to Wispr Flow for macOS.** Hold a key, talk and let go. Clean text lands wherever you were typing, in any app.

- **$0.** Speech-to-text runs on your Mac with [whisper.cpp](https://github.com/ggml-org/whisper.cpp), in about 0.9 s on an M4 Pro.
- **Fixes what you meant.** An optional Claude Haiku pass removes filler words, applies self-corrections ("Tuesday, no wait, Thursday") and spells names the way they already appear on your screen.
- **Small.** About 500 lines of Swift, with no dependencies beyond whisper.cpp.

> "Um, so, hey Sarah, I think we should, uh, ship the onboarding fix on Tuesday. No wait, Thursday."
> → "Hey Sarah, I think we should ship the onboarding fix on Thursday."

## Quick start

```sh
git clone https://github.com/eliotb26/wispr-local.git
cd wispr-local
./scripts/setup.sh                 # installs whisper.cpp, downloads the model, builds
swift run -c release wispr-local
```

Once it prints `ready`, hold **right Option**, talk, and let go. You'll hear a *tink* when recording starts and a *pop* when it stops. Press `Ctrl+C` to quit.

**The first time**, macOS asks for two permissions for your terminal app (Terminal, Ghostty, iTerm…). Grant both in System Settings → Privacy & Security, then restart wispr-local:
- **Microphone**, to record your voice
- **Accessibility**, for the global hotkey, reading the focused field and pasting

The very first dictation takes about 12 seconds while whisper compiles its GPU shaders. After that it's fast.

## Options

| Flag | What it does |
|---|---|
| *(none)* | Whisper, then Claude cleanup |
| `--raw` | Whisper only: fully offline, faster, keeps filler words |
| `--lang <code>` | Spoken language, such as `es` or `auto` (default `en`) |
| `--help` | Show usage |

The cleanup step uses the [Claude Code](https://claude.com/claude-code) CLI (`claude`) and your existing plan, so no API key is needed. Without it, use `--raw`.

## How it works

```
right ⌥ down ─► capture context: frontmost app + focused field text (Accessibility)
             └► record mic → 16 kHz mono WAV
right ⌥ up   ─► whisper-cli, local, on the GPU
             ─► claude -p --model haiku: cleanup with screen context (skipped under 5 words)
             ─► save clipboard → set text (concealed type) → ⌘V → restore clipboard after 500 ms
```

The clipboard swap is invisible: your clipboard comes back half a second later, unless you copied something else in the meantime. The text is marked `org.nspasteboard.ConcealedType`, so clipboard managers don't record it.

| Path | Job |
|---|---|
| `Sources/WisprLocalCore/` | Pure logic, unit-tested: options, cleanup rules and prompt, timing log |
| `Sources/wispr-local/main.swift` | Startup, permissions, hotkey |
| `Sources/wispr-local/Controller.swift` | One dictation at a time, from key down to paste |
| `Sources/wispr-local/Recorder.swift` | Microphone to 16 kHz WAV |
| `Sources/wispr-local/Context.swift` | Frontmost app and focused-field text |
| `Sources/wispr-local/Pipeline.swift` | whisper.cpp and the Claude cleanup call |
| `Sources/wispr-local/Paster.swift` | Clipboard swap, ⌘V, restore |
| `Sources/wispr-local/Shell.swift` | Process runner with timeouts |

## Speed (M4 Pro)

| Step | Time |
|---|---|
| Transcription, warm | ~0.9 s |
| Cleanup via the Claude Code CLI | 2–5 s, mostly CLI startup |

Each dictation appends its timings (audio length, word count, asr/llm/total ms and app name) to `runs.csv`. **The dictated text is never logged.**

## Privacy

Audio and transcription stay on your Mac. With cleanup on, the transcript, the frontmost app's name and up to 1,500 characters of the focused field are sent to Claude. With `--raw`, nothing leaves your machine.

## Known gaps

- **Cleanup latency.** The Claude Code CLI starts fresh on every call. A direct API call or a local model would get it to about a second.
- **Hold-to-talk only.** No hands-free toggle, menu bar icon or launch-at-login yet.
- **Paste-blocking fields.** Paste uses ⌘V, so fields that block paste won't receive the text.
- **Permissions.** Accessibility is granted to the terminal running it, not to a standalone app.

## Development

```sh
swift build -c release
swift test        # needs full Xcode for Swift Testing:
                  # DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## License

MIT. Not affiliated with or endorsed by Wispr. "Wispr Flow" is a trademark of its owner.
