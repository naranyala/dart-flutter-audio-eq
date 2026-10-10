# Audio EQ — Flutter starter (Linux + Android first)

Early-stage cross-platform audio equalizer. **Working today** on Linux and
Android: real DSP core (tested RBJ biquads), preamp, audible audition player
with true-bypass toggle, live response curve, 17 built-in presets, and APO
preset import/export. Native system-wide engines (Android `Equalizer` API,
Linux PipeWire) plug in behind the `EqEngine` interface; macOS/Windows folders
are scaffolded for later.

## Status

| Platform | Tier | State |
|---|---|---|
| Linux | 1 — now | UI + DSP + audible audition (needs libmpv, see below) |
| Android | 1 — now | UI + DSP + audible audition; native engine next (`MODIFY_AUDIO_SETTINGS` set) |
| macOS / Windows | 2 — planned | UI preview only |

## Quick start

```bash
flutter pub get && flutter analyze && flutter test
flutter run -d linux        # or: bash tool/run-linux.sh (handles libmpv)
flutter run -d android      # needs SDK licenses: flutter doctor --android-licenses
```

Build tools (AlmaLinux/Fedora): `sudo dnf install clang cmake ninja-build pkg-config gtk3-devel`.
Linux playback needs system **libmpv** (`sudo dnf install mpv-libs`, or the rootless
`tool/setup-linux-audio.sh`). Details → [`docs/linux-audio.md`](docs/linux-audio.md).

## Features

- **5-band EQ** (60/230/910/3.6k/14k Hz, ±12 dB) + enable bypass, reset, 17 presets
- **Preamp** (−24…+12 dB) against clipping; persisted with gains + toggle
- **Audible audition** — temp file rendered from current state, hot-swapped
  preserving position; your own WAV files EQ'd, other formats play direct
- **Transport** — play/pause, seek bar, loop, session-id readout
- **Response curve** drawn live from the same DSP that renders audio
- **APO `.txt` import/export** (preamp + PK/LS/HS) — Peace/AutoEQ/Resonance compatible

## Docs

- [`docs/architecture.md`](docs/architecture.md) — module map, data flows, rules
- [`docs/linux-audio.md`](docs/linux-audio.md) — playback stack, libmpv bootstrap, troubleshooting
- [`docs/dsp.md`](docs/dsp.md) — filters, render path, test strategy, limits
- [`docs/presets.md`](docs/presets.md) — the 17 presets, APO format subset, roadmap
- [`docs/contributing.md`](docs/contributing.md) — commands, test rules, commit style
- [`PYRAMID-OF-INTENTS.md`](PYRAMID-OF-INTENTS.md) — vision → goals → epics
- [`TODOS.md`](TODOS.md) — phased tracker (15 done / 22 open / 1 blocked)

## Research behind this project

- [comparative-study-of-audio-eq](https://github.com/naranyala/comparative-study-of-audio-eq) —
  OS hook mechanisms, reference apps (Equalizer314, Resonance, EasyEffects), formats
- [awesome-audio-processing](https://github.com/naranyala/awesome-audio-processing) —
  DSP frameworks, analyzer libraries, EQ Cookbook math

## License

No LICENSE file yet — GPL-3.0 proposed (consistent with the Equalizer314
reference and the "free, open" vision). Decide before importing GPL-derived
code or accepting contributions.
