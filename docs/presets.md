# Presets

Bands: 60 / 230 / 910 / 3.6k / 14k Hz, ±12 dB, Q fixed at 1.0 (per-band Q is
a tracked P1 task). Gains below are 5-band approximations of the canonical
graphic-EQ curves for each use case.

## Built-in library (17)

| Preset | 60 | 230 | 910 | 3.6k | 14k | Intent |
|---|---|---|---|---|---|---|
| Flat | 0 | 0 | 0 | 0 | 0 | reference / bypass starting point |
| Bass Boost | 6 | 4 | 0 | 0 | 0 | small speakers, bass-light headphones |
| Bass Cut | -5 | -3 | 0 | 0 | 0 | boomy rooms, bleed control |
| Treble Boost | 0 | 0 | 0 | 4 | 6 | dull recordings |
| Warm | 1 | 1 | 0 | -3 | -5 | harsh/shouty material |
| Loudness | 5 | 3 | 0 | 1 | 4 | low-volume Fletcher-Munson compensation |
| Vocal | -2 | 0 | 3 | 3 | 1 | forward voice in mixes |
| Podcast | -5 | -2 | 2 | 4 | 2 | speech: rumble/plosive cut + presence |
| Rock | 5 | 3 | -2 | 2 | 5 | classic smile with guitar presence |
| Pop | 4 | 2 | 0 | 2 | 4 | polished all-rounder lift |
| Hip-Hop | 7 | 4 | -1 | 1 | 5 | heavy low end, crisp top |
| Electronic | 6 | 3 | 0 | 2 | 5 | dance weight + synth sheen |
| Jazz | 4 | 3 | 1 | 2 | 3 | warm restraint |
| Classical | 3 | 1 | 0 | 1 | 3 | gentle hall feel |
| Metal | 6 | 3 | -4 | 3 | 6 | aggressive mid scoop |
| Late Night | -3 | -1 | 2 | 3 | 2 | quiet listening, clear dialogue |
| Gaming | -2 | 0 | 4 | 5 | 3 | footstep presence, de-boomed lows |

Per-headphone measured corrections do **not** belong here — those are the
AutoEQ bundle (`TODOS.md` P0), which will dwarf this list.

## Equalizer APO `.txt` interchange

Supported subset (v1):

```
Preamp: -6 dB
Filter 1: ON PK Fc 1000 Hz Gain 3.5 dB Q 1.00
Filter 2: ON LS Fc 100 Hz Gain 2.0 dB
Filter 3: ON HS Fc 10000 Hz Gain -1.5 dB
```

- `ON`/`OFF`: OFF lines skipped. `#`/`;` comments and blanks ignored.
- `PK`/`LS`/`HS` supported; other ON types throw `FormatException`
  (surfaced in a SnackBar). Q optional, defaults to 1.0.
- Import maps preamp → preamp and each filter to its nearest band
  (log-distance); export writes one PK line per band + preamp and
  round-trips through the parser (tested).
- Compatible with Equalizer APO, Peace, AutoEQ exports, Resonance.

## Roadmap

Named user presets with CRUD (`SharedPreferences` JSON map) and a searchable
browser over the AutoEQ bundle (model-name search, source attribution).
Tracked in `TODOS.md` P1 `[E2/G3]`.
