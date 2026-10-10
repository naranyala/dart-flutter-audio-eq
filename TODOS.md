# TODOS — audio_eq

Parent intent for every item: `PYRAMID-OF-INTENTS.md`. Tags `[Ex/Gx]` point at
the epic and goal each task serves. Phase order is intentional — finish P0
before starting P1.

Legend: `[ ]` open · `[x]` done · `[~]` in progress / blocked (note why).

## P0 — Make it real (audible EQ on Tier 1)

- [x] Starter scaffold: app + `EqEngine` contract + mock UI on Linux/Android
- [x] `[E3/G4]` Pure-Dart RBJ biquads (`lib/features/dsp/biquad.dart`):
      peaking + low/high shelf from W3C EQ Cookbook; 7 unit tests
      (flat transparency, ±6 dB gain, selectivity, shelf direction)
- [x] `[E3/G4]` Offline WAV render (`lib/features/dsp/offline_render.dart`,
      `package:wav`): `renderEqOnWav` + RIFF serialization; 3 tests
- [x] `[E2/G3]` Equalizer APO `.txt` import/export
      (`lib/features/eq/data/apo_preset.dart`): preamp + PK/LS/HS, OFF skip,
      round-trip serialize; 5 tests
- [x] `[E2/G3]` File UX (`file_picker` + `share_plus` + `path_provider`):
      `PresetFileService` + import/share buttons in `EqPage` AppBar
- [x] `[E5/G5]` FFT helper (`lib/features/dsp/spectrum.dart`, `package:fft`):
      `peakFrequency` + Hann-windowed `magnitudeSpectrum`; 3 tests —
      live-capture wiring still open (see P1)
- [x] `[E4/G1,G2]` Wired `AudioPlayerService` into the app: Riverpod provider,
      `_PlayerBar` transport + session-id display, generated
      `assets/samples/demo.wav` audition loop (`tool/make_demo_wav.py`),
      Linux playback via `just_audio_media_kit` + `media_kit_libs_linux`
      (needs system libmpv — see README); `TransportRow` split out pure
      for tests
- [x] `[E4/G1,G2]` Render-based audible audition (the toggle is real now):
      player source is a temp `audition.wav` rendered from current state
      (`renderAudition`: bypass serves the untouched demo); every EQ
      mutation hot-swaps the source preserving position/playing; first
      play prepares lazily; 3 helper + 3 controller tests. Chosen over
      live byte-streaming because the Linux backend only supports
      URI/file sources (`StreamAudioSource` throws there).
- [x] `[E7]` Toggle persistence: `eq_enabled` in `PresetRepository`,
      restored in `init`, covered by restart test
- [ ] `[E2/G3]` Bundle ≥20 AutoEQ-derived headphone presets as app assets with
      attribution; show source in UI
- [ ] `[E1/G1]` Android engine modeled on Equalizer314: MethodChannel
      `com.audioeq/eq` + `android.media.audiofx.Equalizer` on the
      `just_audio` session id; fallback to mock on failure; verify on a real
      device (emulator DSP is unreliable)
- [ ] `[E6/G2]` Linux system-wide path (in-app audition already audible via
      render flow): export a PipeWire filter-chain preset
      (squigwire/eq-cli pattern); document exact PipeWire version +
      commands in README
- [ ] `[E7/*]` Quality gates green: `flutter analyze` clean, `flutter test`
      green, `flutter build linux --debug` green; record Android device result

## P1 — Make it trustworthy and observable

- [x] `[E3/G4]` Preamp gain: `preampDb` in `EqState` + `EqEngine.setPreamp`
      (−24…+12 dB) + UI slider + persistence; APO import routes preamp to
      preamp (no band smear), export writes the real preamp; offline render
      applies it; 5 controller tests + preamp render test
- [x] `[E5/G5]` Static EQ response curve widget (`EqCurveWidget`: log-freq
      CustomPainter from tested `EqChain.magnitudeAt`, band markers, preamp
      included) integrated in `EqPage`
- [ ] `[E3/G4]` Truly parametric editing: per-band Q (+ filter type PK/LS/HS)
      in UI with persistence; `Biquad.notch` factory to close the pyramid's
      "peaking/shelf/notch" promise; unit tests
- [ ] `[E2/G3]` Named preset store: CRUD over a `SharedPreferences` JSON map
      (or preset files), migrate today's last-used gains; unit tests
- [ ] `[E2/G3]` Preset library UI: searchable browser over the AutoEQ bundle
      (model-name search, measurement-source attribution, apply + save a copy);
      replaces the `ChoiceChip` row once the bundle exceeds ~8 items
- [ ] `[E3/G4]` Extend render demo: sample WAV asset + "render + save" flow
      reusing `renderEqOnWav` (core already done); golden-file test
- [ ] `[E5/G5]` Live spectrum: Android `Visualizer` API capture (Equalizer314
      pattern); Linux FFT path reusing tested `Spectrum`; both behind the
      same widget
- [ ] `[E4/G1,G2]` A/B audition extras: blind-toggle (enable switch already
      gives honest bypass); session-id in bug reports (already displayed)
- [ ] `[E7/*]` Engine conformance tests: same gain/enable/clamp suite runs
      against mock + Android + any future backend

## P2 — Tier 2 + shippable

- [ ] `[E1/G6]` macOS backend: `AVAudioUnitEQ` in `AVAudioEngine` path,
      implements `EqEngine`, swapped in `main.dart` only
- [ ] `[E1/G6]` Windows backend: WASAPI post-mix DSP or APO integration note,
      same swap rule; document signing/driver constraints
- [ ] `[E6/G6]` Flip `PlatformInfo.hasNativeDsp` per platform as backends land;
      Tier-2 banner disappears platform by platform
- [ ] `[E7/*]` CI (GitHub Actions or equivalent): analyze + test + Linux build
      on push; Android build on tag; `flutter pub outdated` monthly
- [ ] `[E7/G7]` Real-device matrix before any release claim: Android API levels
      × PipeWire versions actually tested, recorded in README
- [ ] `[E8/G7]` Release track: app icon + splash + display name; Android signing
      + release AAB/APK; Linux packaging (pick ONE: Flatpak/AppImage/deb);
      Play listing + privacy policy + data-safety form; versioning scheme

## Backlog (do NOT promote without a goal)

- DAW plugin formats (VST/AU/LV2/CLAP) — needs a goal first, currently non-goal
- Room-correction measurement (REW-style) — needs a goal first
- Convolution / FIR engine (CamillaDSP-class) — only if IIR proves insufficient
- Per-app profiles, loudness compensation, crossfeed — capture as G/E first
- Background playback / foreground service — conditional on engine
  architecture (needed for own-player EQ, unnecessary for system-wide EQ)
- First-run onboarding (preview-vs-native explainer) — needs a goal first
- i18n — needs a goal first
- Cloud sync / accounts — explicitly out of scope until vision changes

## Working agreement

- One task in flight at a time; check `[~]` with date + blocker when paused.
- Every PR/todo completion names its `[Ex/Gx]`; pyramid violations get
  re-scoped, not merged.
- Review monthly: promote at most 2 backlog items, retire stale ones.
