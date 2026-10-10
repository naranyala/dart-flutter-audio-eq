import 'package:wav/wav.dart';

import '../dsp/offline_render.dart';

/// What the audition player actually plays.
///
/// The enable toggle is honest: enabled → current gains + preamp rendered
/// into the demo; disabled → the untouched demo (true bypass). Rendered with
/// the same tested [renderEqOnWav] as the offline flow, so what you hear is
/// what the curve shows.
///
/// Render-to-file (not a live byte stream) because the Linux playback
/// backend (`just_audio_media_kit`) only supports URI/file sources — custom
/// `StreamAudioSource` throws there. One code path works on both Tier-1
/// platforms.
Wav renderAudition({
  required Wav base,
  required List<double> freqsHz,
  required List<double> gainsDb,
  required double preampDb,
  required bool enabled,
}) {
  if (!enabled) return base;
  return renderEqOnWav(
    base,
    freqsHz: freqsHz,
    gainsDb: gainsDb,
    preampDb: preampDb,
  );
}
