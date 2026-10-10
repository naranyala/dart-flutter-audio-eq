import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wav/wav.dart';

/// Decode an audio file to a [Wav] for our render path.
///
/// Status: WAV parses directly (unit-testable, zero system deps). Anything
/// else currently throws [FormatException] and the caller falls back to
/// direct (unequalized) play.
///
/// Decision record (see TODOS `[E3/G4]`, blocked): `package:audio_decoder`
/// (MIT, native APIs) was selected and then reverted — its Linux build needs
/// GStreamer *dev* packages (`gstreamer1-devel`,
/// `gstreamer1-plugins-base-devel`) absent from locked-down machines.
/// One install re-enables it; the pure-Dart (`dart_flac` 0.0.x) and narrow
/// FFI (`audio_decode`: MP3/Vorbis only) alternatives were rejected, and
/// miniaudio-via-FFI remains the system-dep-free candidate (see capture
/// spike task).
class DecodedAudio {
  const DecodedAudio({
    required this.wav,
    required this.formatLabel,
    required this.wasConverted,
    this.decodedPath,
  });

  final Wav wav;
  final String formatLabel;
  final bool wasConverted;

  /// Temp output path when a conversion happened (caller deletes the
  /// previous one on next open — these accumulate otherwise).
  final String? decodedPath;
}

Future<DecodedAudio> decodeToWav(String path, Directory _) async {
  final ext = path.split('.').last.toUpperCase();
  if (ext == 'WAV') {
    try {
      final bytes = await File(path).readAsBytes();
      return DecodedAudio(
        wav: Wav.read(bytes),
        formatLabel: 'WAV',
        wasConverted: false,
      );
    } catch (e) {
      throw FormatException('Not a readable WAV file: $path ($e)');
    }
  }
  // Non-WAV decode is wired for `package:audio_decoder` but reverted: see
  // module doc (the Directory param is reserved for decoder output then).
  throw FormatException(
    'No decoder available for .$ext here (needs audio_decoder + '
    'GStreamer dev packages, or the miniaudio-FFI spike)',
  );
}

/// Format label from a file name, e.g. `song.MP3` → `MP3`.
String formatOf(String name) =>
    name.contains('.') ? name.split('.').last.toUpperCase() : '?';

@visibleForTesting
bool isWavPath(String path) => path.toLowerCase().endsWith('.wav');
