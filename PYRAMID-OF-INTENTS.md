# Pyramid of Intents — audio_eq

How to read this file: top = stable, long-lived intent. Bottom = concrete,
changeable work. Higher levels constrain lower levels — a TODO that conflicts
with a level above it is wrong and must be re-scoped, not the other way round.

```
            L0 VISION (why this exists)
            L1 MISSION + PRINCIPLES (how we behave)
            L2 STRATEGIC GOALS (what winning looks like)
            L3 EPICS / CAPABILITIES (system must do X)
            L4 TASKS (work items) → see TODOS.md
```

---

## L0 — Vision

A free, open, cross-platform audio equalizer that a user can trust with their
daily listening: correct sound first, beautiful UI second, every platform
eventually.

- Tier 1 now: **Linux + Android**.
- Tier 2 later: **macOS + Windows** (folders already scaffolded, no rewrites).
- iOS explicitly out of scope (OS forbids system-wide audio interception).

## L1 — Mission + Principles

Mission: ship the smallest EQ that is **audibly real** on Tier 1, then expand
platform coverage without forking the app.

Principles (in priority order):

1. **Correctness over features.** A 5-band EQ that truly changes sound beats a
   31-band mock. No fake sliders — preview mode must be labeled as such.
2. **One app, many backends.** UI talks only to `EqController`; DSP only
   through the `EqEngine` contract. Platform code never leaks into widgets.
3. **Open formats first.** Support Equalizer APO `.txt` and AutoEQ profiles
   before inventing a proprietary preset format.
4. **Reference before invention.** Copy proven hook mechanisms (Android
   `DynamicsProcessing`, Linux PipeWire filter-chain) and proven DSP (RBJ
   biquad cookbook) instead of designing new ones.
5. **No root, no hacks.** Reject AudioFlinger mods, driver injection, or
   anything requiring rooted devices / unsigned drivers.
6. **Test the contract.** Every engine implements the same 4-method interface
   and passes the same conformance tests.

## L2 — Strategic goals

| ID | Goal | Done when |
|----|------|-----------|
| G1 | Audible EQ on Android | Sliders drive `android.media.audiofx` via MethodChannel on a real device; labeled preview mode disappears on Android |
| G2 | Audible EQ path on Linux | App exports/activates a PipeWire filter-chain preset **or** renders EQ'd audio locally; user hears the change |
| G3 | Preset library worth opening the app for | APO `.txt` import + built-in AutoEQ-derived presets (at least 20 headphone profiles) |
| G4 | Trustworthy DSP core | Pure-Dart RBJ biquads with unit tests (flat ≈transparent, +6 dB ≈ ×2 amplitude, clamping respected) |
| G5 | Observable sound | Spectrum/response visualization so users see what they hear |
| G6 | Tier-2 ready | macOS (`AVAudioUnitEQ`) and Windows (WASAPI/APO) backends implement `EqEngine` with zero UI changes |
| G7 | Installable on Tier 1 | Signed Android release + Linux package + store listing ready; a stranger can install it |

Non-goals (explicit): system-wide iOS EQ, root-only Android DSP, DAW plugin
formats (VST/AU/LV2/CLAP), room-correction measurement (REW-style), accounts /
cloud sync / subscriptions.

## L3 — Epics / Capabilities

- **E1 Engine abstraction** — `EqEngine` contract + per-platform backends
  (`MockEqEngine` today; `AndroidEqualizerEngine`, PipeWire exporter next).
  Conformance tests per backend.
- **E2 Preset system** — built-ins (Flat/Bass/Vocal/Treble) → APO `.txt`
  import → AutoEQ profile bundle → searchable headphone-match browser →
  named user presets (CRUD) with persistence.
- **E3 DSP core** — pure-Dart biquads (peaking/shelf/notch from the W3C EQ
  Cookbook), per-band Q + filter-type editing, preamp gain control, offline
  render path (WAV today, decoded formats next), scipy golden-vector
  validation, later FFI/C++ only if profiling demands it.
- **E4 Auditioning** — `just_audio` + `audio_session` transport wired into the
  app (provider + UI + sample asset), user-file/URL playback, complete
  transport (seek/loop/time), debounced re-render, expose Android session id
  for A/B checks and bug reports.
- **E5 Visualization** — static EQ curve now (free, no permissions), live
  spectrum later (Android `Visualizer` API / Linux FFT).
- **E6 Platform wiring** — MethodChannel `com.audioeq/eq`, manifest
  permissions (`MODIFY_AUDIO_SETTINGS` done), PipeWire preset export, Tier-2
  stubs behind `PlatformInfo.hasNativeDsp`.
- **E7 Quality gates** — `flutter analyze` clean, `flutter test` green, Linux
  debug build green, Android build on demand; CI when the repo goes remote;
  real-device matrix (Android API levels, PipeWire versions) before release.
- **E8 Release & distribution** — LICENSE file first, then icon/splash/name,
  Android signing + release artifacts, Linux packaging (one format) +
  desktop citizenship (MPRIS, file association, tray), store listing +
  privacy policy, versioning scheme.

## L4 — Tasks

Lives in `TODOS.md`. Every task carries its epic + goal tags (e.g.
`[E2/G3]`). If a task has no parent goal, either the pyramid is incomplete or
the task doesn't belong — resolve before coding.
