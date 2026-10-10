# Audio EQ — Flutter starter (Linux + Android first)

Early-stage cross-platform audio equalizer. **Working today** on Linux
desktop and Android: real DSP core (tested RBJ biquads), preamp control,
audition player with demo loop, live response curve, offline WAV rendering,
and APO preset import/export. Native system-wide engines (Android
`Equalizer` API, Linux PipeWire) plug in behind the `EqEngine` interface so
macOS / Windows can land later without rewriting the app.

## Status

| Platform | Tier | State |
|---|---|---|
| Linux | 1 — now | UI + DSP core + demo playback (`just_audio_media_kit`), WAV render |
| Android | 1 — now | UI + DSP core + demo playback, `MODIFY_AUDIO_SETTINGS` in manifest; native engine next |
| macOS | 2 — planned | UI preview only |
| Windows | 2 — planned | UI preview only |

## Quick start

```bash
flutter pub get
flutter analyze
flutter test

# Linux desktop (works now; needs media_kit libs, pulled via pub)
flutter run -d linux

# Android (needs SDK licenses + device/emulator)
flutter run -d android
```

Linux native deps (AlmaLinux / Fedora):

```bash
sudo dnf install clang cmake ninja-build pkg-config gtk3-devel
```

Demo-loop playback on Linux additionally needs system **libmpv**
(`media_kit` does not bundle it):

```bash
# Proper fix (needs sudo):
sudo dnf install mpv-libs        # AlmaLinux/Fedora (RPM Fusion)
sudo apt install libmpv2         # Debian/Ubuntu

# Rootless workaround (no sudo) — downloads + extracts the RPMs to
# ~/.local/share/audio_eq/libs, then launches with them:
bash tool/setup-linux-audio.sh
bash tool/run-linux.sh
```

Decoding user files (MP3/FLAC/OGG/…) needs the `audio_decoder` plugin,
which in turn needs GStreamer dev packages at *build* time:

```bash
# Debian/Ubuntu:
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
# AlmaLinux/Fedora:
sudo dnf install gstreamer1-devel gstreamer1-plugins-base-devel
```

Without them the app still builds and runs — WAV renders with EQ, other
formats play direct with notice (runtime GStreamer plugins are preinstalled
on most desktop distros).

Without libmpv the app still runs fully — the player bar shows a notice
instead of a dead play button, and offline WAV rendering works regardless.

Android setup (cmdline-tools + licenses are required — see `flutter doctor`):

```bash
flutter doctor --android-licenses
flutter emulators  # or plug in a device
```

## What's in the app

- **5-band EQ** (60 / 230 / 910 / 3.6k / 14k Hz, ±12 dB) with enable bypass,
  reset, and 17 built-ins: Flat; tone fixes (Bass Boost/Cut, Treble Boost,
  Warm, Loudness); voice (Vocal, Podcast); genres (Rock, Pop, Hip-Hop,
  Electronic, Jazz, Classical, Metal); scenarios (Late Night, Gaming).
- **Preamp** (−24…+12 dB) — headroom control that boosted presets (e.g. AutoEQ
  corrections) need to avoid clipping.
- **Response curve** — the combined filter response drawn live from the same
  tested DSP code that renders audio.
- **Audition player** — bundled 6 s `demo.wav` loop with transport bar and
  audio session-id readout (the id the future Android engine attaches to).
  The source is a temp `audition.wav` rendered from the *current* EQ state:
  the enable toggle is a true bypass, and every slider move hot-swaps the
  source preserving position/playing. File-based (not live-streamed) because
  the Linux backend only supports URI/file sources — identical behavior on
  Android and Linux.
- **Your own files** — open any audio file (music-note button): WAV runs
  through the full EQ render path (MP3/FLAC/OGG decode is selected but
  blocked on GStreamer dev packages — see `TODOS.md`; until then non-WAV
  plays direct with an "original (no EQ)" notice). Track label shows
  `name · FORMAT · EQ`.
- **Transport** — play/pause, seek bar with elapsed/total time, single-track
  loop, session id. Slider drags coalesce renders (250 ms debounce).
- **Preset interchange** — import/export Equalizer APO `.txt`
  (`Preamp:` + `PK`/`LS`/`HS` filters) via the folder/share buttons.
  Compatible with Equalizer APO, Peace, AutoEQ exports, Resonance.

## Architecture

```
lib/
  main.dart                  # ProviderScope + eqEngineProvider (swap point)
  app.dart                   # MaterialApp + light/dark theme
  core/platform/             # PlatformInfo gating (Tier 1 vs Tier 2)
  features/dsp/              # Biquad, EqChain, offline_render (wav), spectrum (fft)
  features/eq/
    domain/                  # EqBand, EqPreset, EqEngine (contract)
    data/                    # MockEqEngine, PresetRepository, APO parser, file service
    presentation/            # EqController (Riverpod), EqPage, BandSlider, EqCurve
  features/player/           # AudioPlayerService (just_audio), TransportRow
assets/samples/demo.wav      # generated audition loop (see tool/)
tool/make_demo_wav.py        # regenerates demo.wav — no binary-blob mystery
test/                        # 30 unit + widget tests (DSP, parser, render, controller, UI)
PYRAMID-OF-INTENTS.md        # vision → goals → epics (read this first)
TODOS.md                     # phased task tracker, tagged [Epic/Goal]
```

Rules:

- UI talks only to `EqController`, never to platform channels.
- All DSP goes through `EqEngine`. Add native engines by implementing
  the interface and swapping `eqEngineProvider` in `main.dart`.
- No embedded interpreters; Python lives in `tool/` (asset generation,
  golden vectors), never in the app. Native code (if ever needed) goes
  through one narrow `dart:ffi` module — see `TODOS.md` backlog.

Key third-party packages: `flutter_riverpod` (state), `just_audio` +
`just_audio_media_kit` + `media_kit_libs_linux` (playback, incl. Linux),
`audio_session`, `shared_preferences` (persistence), `wav` (offline render),
`fft` (spectrum helpers), `file_picker` + `share_plus` + `path_provider`
(preset import/export).

## Wiring real DSP (roadmap)

### Android (next)

1. Playback + session id already exposed by `AudioPlayerService`.
2. Add a `MethodChannel('com.audioeq/eq')` in `MainActivity.kt`.
3. Drive `android.media.audiofx.Equalizer` (Equalizer314 pattern):
   `setBandLevel(band, levelMillibels)`, `setEnabled`.
4. Keep `MockEqEngine` for the emulator-without-DSP fallback.

Manifest already contains `MODIFY_AUDIO_SETTINGS`.

### Linux

Options in order of effort:

1. System EQ shortcut: write PipeWire/Pulse filter-chain preset
   (EasyEffects schema) and let the user apply it.
2. Already works: offline render (`renderEqOnWav`) — EQ any WAV file.
3. Later: capture path for the live visualizer (miniaudio via FFI candidate).

### macOS / Windows (Tier 2)

- macOS: `AVAudioUnitEQ` inside an `AVAudioEngine` render path.
- Windows: WASAPI post-mix DSP or an APO plugin.
- Both reuse the same `EqEngine` contract; only `main.dart` wiring changes.

## Conventions

- 5 bands default: 60 / 230 / 910 / 3.6k / 14k Hz, ±12 dB; Q fixed at 1.0
  (per-band Q editing is a tracked P1 task).
- Presets persisted with `shared_preferences` (`eq_gains_db`,
  `eq_preset_name`, `eq_preamp_db`).
- State: `flutter_riverpod` `StateNotifier` (simple, testable).
- Regenerate the demo asset with `python3 tool/make_demo_wav.py`.

## Research behind this project

- [comparative-study-of-audio-eq](https://github.com/naranyala/comparative-study-of-audio-eq) —
  hook mechanisms per OS (DynamicsProcessing, PipeWire filter-chain),
  reference apps (Equalizer314, Resonance, EasyEffects), APO/AutoEQ formats.
- [awesome-audio-processing](https://github.com/naranyala/awesome-audio-processing) —
  DSP/plugin frameworks, analyzer libraries, EQ Cookbook DSP math.
