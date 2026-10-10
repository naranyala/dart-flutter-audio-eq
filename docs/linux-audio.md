# Linux audio

## Playback stack

```
EqController → AudioPlayerService → just_audio
    → just_audio_media_kit (ensureInitialized in main.dart)
      → media_kit → system libmpv → PipeWire/Pulse/ALSA
```

`media_kit_libs_linux` ships **no** libmpv (verified: its CMake bundles an
empty library list) — the library must come from the system.

## Getting sound

Preferred (needs sudo):

```bash
sudo dnf install mpv-libs        # AlmaLinux/Fedora (RPM Fusion)
sudo apt install libmpv2         # Debian/Ubuntu
```

Rootless (no sudo, verified on AlmaLinux 10):

```bash
bash tool/setup-linux-audio.sh   # downloads + extracts RPMs to ~/.local/share/audio_eq/libs
bash tool/run-linux.sh           # prefers system libmpv, else uses the stack
```

Without libmpv the app still runs fully — the player bar shows a notice,
and offline WAV rendering works regardless.

## Design constraints on Linux

- **File sources only.** The mpv backend supports URI/file playback;
  `StreamAudioSource` (live byte streaming) throws there. Hence the
  render-to-temp-file audition design — identical behavior on Android
  and Linux by construction.
- **Session ids are Android-only.** `androidAudioSessionId` is null on Linux;
  the readout shows `session —` until the native engine exists.
- **No system-wide EQ yet.** In-app audition is audible; intercepting other
  apps' audio needs the PipeWire filter-chain exporter (`TODOS.md` P0).

## User-file decoding

WAV parses in pure Dart. MP3/FLAC/OGG decode was assigned to
`package:audio_decoder` (MIT, native APIs, GStreamer on Linux) but reverted:
its Linux *build* needs GStreamer dev packages
(`gstreamer1-devel gstreamer1-plugins-base-devel`). Runtime plugins are
preinstalled on most desktop distros — one install re-enables the whole
path. Until then non-WAV plays direct with notice. Pure-Dart
(`dart_flac` 0.0.x) and narrow FFI (`audio_decode`: MP3/Vorbis only) were
rejected; miniaudio-via-FFI is the system-dep-free candidate.

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| "Demo audio unavailable" notice | no libmpv → install or run `tool/run-linux.sh` |
| MP3 plays "original (no EQ)" | decode blocked (above) — WAV gets full EQ today |
| No sound though playing | check sink volume + `pw-play FILE.wav` as a backend-independent test |
| `flutter build linux` fails on GStreamer | only if re-adding `audio_decoder` without dev packages |
| Build tools missing | `sudo dnf install clang cmake ninja-build pkg-config gtk3-devel` |
