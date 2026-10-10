# Architecture

One app, many backends. UI talks only to `EqController`; all DSP goes
through the `EqEngine` contract; platform code never leaks into widgets.

## Module map

```
lib/
  main.dart                  # ProviderScope, eqEngineProvider, mpv init
  app.dart                   # MaterialApp + light/dark theme
  core/platform/             # PlatformInfo Tier-1/Tier-2 gating
  features/dsp/              # pure-Dart DSP, no plugins, fully tested
    biquad.dart              # RBJ peaking/low-shelf/high-shelf + EqChain
    offline_render.dart      # renderEqOnWav / renderEqMono (+ preamp)
    spectrum.dart            # Hann-windowed FFT helpers (package:fft)
    audio_decode.dart        # WAV parse; non-WAV decode (blocked, see below)
  features/eq/
    domain/                  # EqBand, EqPreset, EqEngine contract
    data/                    # MockEqEngine, PresetRepository, APO parser,
                             # PresetFileService (pick/share)
    presentation/            # EqController, EqPage, BandSlider, EqCurve
  features/player/           # AudioPlayerService, audition_source,
                             # TransportRow + SeekBar
assets/samples/demo.wav      # generated loop (tool/make_demo_wav.py)
tool/                        # make_demo_wav.py, setup-linux-audio.sh,
                             # run-linux.sh (Python/shell live here, never in app)
test/                        # 53 unit + widget tests
```

## Data flows

**Slider drag → sound:** `BandSlider` → `EqController.setGain` (clamp ±12) →
`MockEqEngine.setBandGain` + persist → debounced (250 ms) `_refreshAuditionSource` →
`renderAudition` → temp `audition.wav` → `setFilePath` preserving position,
resuming if playing. Refreshes serialize; overlap coalesces to one trailing run.

**Toggle:** `setEnabled` persists `eq_enabled`, renders bypass (untouched demo
bytes, bit-exact) or processed file immediately — no debounce on discrete gestures.

**First play:** no source exists until then; `toggleAudition` prepares
(render → `setFilePath`) then plays. Backend failure → `audioError`, UI shows
a notice instead of a dead button.

**Import:** APO `.txt` → preamp to preamp, bands to nearest band (no smearing)
→ engine + persist + immediate refresh.

**Open file:** picker → WAV parses directly; anything else tries platform
decode (currently blocked — see `docs/linux-audio.md`) and falls back to
direct play with an "original (no EQ)" label.

## Rules

- UI → `EqController` only, never platform channels.
- DSP → `EqEngine` implementations, swapped in `main.dart`.
- No embedded interpreters; Python/shell live in `tool/`.
- Native code (if ever needed) goes through one narrow `dart:ffi` module.
- Failures degrade to notices; a render/playback problem must never break
  slider movement (all refresh paths catch and log).

## State & persistence (`shared_preferences`)

| Key | Content |
|---|---|
| `eq_gains_db` | last-used band gains (JSON) |
| `eq_preset_name` | selected preset name |
| `eq_preamp_db` | preamp gain |
| `eq_enabled` | bypass toggle |

## Providers

`eqEngineProvider` (swap point for native engines) · `presetRepositoryProvider` ·
`eqControllerProvider` · `audioPlayerServiceProvider` (backend failure captured,
never throws).
