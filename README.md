# Audio EQ — Flutter starter (Linux + Android first)

Early-stage cross-platform audio equalizer. UI + state work **today** on
Linux desktop and Android. Real DSP is stubbed behind an `EqEngine`
interface so macOS / Windows can land later without rewriting the app.

## Status

| Platform | Tier | State |
|---|---|---|
| Linux | 1 — now | UI + mock engine, `just_audio` playback |
| Android | 1 — now | UI + mock engine, `MODIFY_AUDIO_SETTINGS` already in manifest |
| macOS | 2 — planned | UI preview only |
| Windows | 2 — planned | UI preview only |

## Quick start

```bash
flutter pub get
flutter analyze
flutter test

# Linux desktop (works now)
flutter run -d linux

# Android (needs SDK licenses + device/emulator)
flutter run -d android
```

Linux native deps (AlmaLinux / Fedora):

```bash
sudo dnf install clang cmake ninja-build pkg-config gtk3-devel
```

Android setup:

```bash
flutter doctor --android-licenses
flutter emulators  # or plug in a device
```

## Architecture

```
lib/
  main.dart                  # ProviderScope + eqEngineProvider (swap point)
  app.dart                   # MaterialApp + light/dark theme
  core/platform/             # PlatformInfo gating (Tier 1 vs Tier 2)
  features/eq/
    domain/                  # EqBand, EqPreset, EqEngine (contract)
    data/                    # MockEqEngine, PresetRepository (shared_prefs)
    presentation/            # EqController (Riverpod), EqPage, BandSlider
  features/player/           # AudioPlayerService (just_audio + audio_session)
```

Rules:

- UI talks only to `EqController`, never to platform channels.
- All DSP goes through `EqEngine`. Add native engines by implementing
  the 4-method interface and swapping `eqEngineProvider` in `main.dart`.

## Wiring real DSP (roadmap)

### Android (next)

1. Get the audio session id from `AudioPlayerService.androidAudioSessionId`.
2. Add a `MethodChannel('com.audioeq/eq')` in `MainActivity.kt`.
3. Drive `android.media.audiofx.Equalizer(priority, sessionId)`:
   `setBandLevel(band, levelMillibels)`, `setEnabled`.
4. Keep `MockEqEngine` for the emulator-without-DSP fallback.

Manifest already contains `MODIFY_AUDIO_SETTINGS`.

### Linux

Options in order of effort:

1. App-local EQ: route `just_audio` through GStreamer `equalizer-10bands`
   (needs a custom audio sink — biggest work).
2. System EQ shortcut: write PipeWire/Pulse filter-chain preset
   (EasyEffects schema) and let the user apply it.
3. Full native: Dart FFI to a small C DSP lib (biquads) for file render.

### macOS / Windows (Tier 2)

- macOS: `AVAudioUnitEQ` inside an `AVAudioEngine` render path.
- Windows: WASAPI post-mix DSP or an APO plugin.
- Both reuse the same `EqEngine` contract; only `main.dart` wiring changes.

## Conventions

- 5 bands default: 60 / 230 / 910 / 3.6k / 14k Hz, ±12 dB.
- Presets persisted with `shared_preferences` (`eq_gains_db`, `eq_preset_name`).
- State: `flutter_riverpod` `StateNotifier` (simple, testable).

## Already working (beyond the mock)

- **Real DSP core** (`lib/features/dsp/`): RBJ biquads (peaking, low/high
  shelf) from the W3C Audio EQ Cookbook, fully unit-tested.
- **Offline WAV EQ** (`package:wav`): `renderEqOnWav()` applies current gains
  to a WAV file — render on Linux, play the output, hear it.
- **APO preset interchange**: import/export Equalizer APO `.txt`
  (preamp + PK/LS/HS) via the folder/share buttons — compatible with
  Equalizer APO, Peace, AutoEQ exports, Resonance.
- **FFT helpers** (`package:fft`): tested `peakFrequency` / spectrum
  functions waiting on live-capture wiring for the visualizer.
