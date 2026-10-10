# DSP core

Pure Dart, zero plugins, fully unit-tested. Same code renders files,
feeds the audition player, and draws the response curve — what you see
is what you hear.

## Filters (`lib/features/dsp/biquad.dart`)

Second-order IIR biquads from the RBJ Audio EQ Cookbook
(<https://www.w3.org/TR/audio-eq-cookbook/>) — the math behind most
parametric EQs worldwide.

- `Biquad.peaking` (freq, Q, gain), `Biquad.lowShelf` / `.highShelf`
  (freq, gain, slope S, default 1), Direct Form I state, `reset()`.
- `EqChain.peaking` — one biquad per band per channel, matching the
  app's 5-band model; `magnitudeAt()` gives the combined response for
  the curve widget without touching audio.
- Coefficients normalize to a0 = 1; 0 dB is bit-transparent up to float
  rounding (asserted in tests).

## Render path (`offline_render.dart`, `audition_source.dart`)

- `renderEqOnWav` / `renderEqMono`: fresh chain per channel (no state
  leakage), adapts to the file's own sample rate, preamp applied as a
  flat post-gain (`10^(dB/20)`).
- `renderAudition`: bypass returns the base object untouched (bit-exact,
  asserted); enabled renders gains + preamp.

## Spectrum (`spectrum.dart`)

Hann-windowed 4096-pt FFT (`package:fft`): `magnitudeSpectrum()` and
`peakFrequency()`, tested on synthetic tones. Reserved for the live
visualizer once a capture path exists (Linux: miniaudio-FFI candidate).

## Test strategy

- Sine-RMS checks: flat ≈ 1.0, +6 dB ≈ ×2, −6 dB ≈ ×½, off-center
  tones nearly untouched, shelf direction (lows vs highs).
- `magnitudeAt` agrees with time-domain gain (curve can't lie).
- Byte-level: bypass round-trips exactly; RIFF header present.
- Planned: `tool/golden_vectors.py` — `scipy.signal` reference vectors
  as test data, to catch coefficient bugs sine tests might miss.

## Limits (honest)

- IIR only — no FIR/convolution (CamillaDSP-class is backlog-gated).
- WAV in/out only for now (see `docs/linux-audio.md` for the decode story).
- Five fixed bands at Q 1.0 until parametric editing lands.
