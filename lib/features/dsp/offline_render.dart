import 'dart:math' as math;
import 'dart:typed_data';

import 'package:wav/wav.dart';

import 'biquad.dart';

/// Offline (file) EQ rendering: apply band gains to a [Wav] without any
/// native audio path.
///
/// This is the first *audible* proof in the project — render on Linux,
/// play the output file, hear the sliders. Each channel gets a fresh
/// [EqChain] so filter state never leaks between channels.
///
/// [preampDb] is applied as a flat post-gain (same role as the engine
/// preamp: headroom control for boosted presets).
Wav renderEqOnWav(
  Wav wav, {
    required List<double> freqsHz,
    required List<double> gainsDb,
    double preampDb = 0,
    double q = 1.0,
  }) {
  final preampLin = math.pow(10, preampDb / 20).toDouble();
  final outChannels = <Float64List>[
    for (final channel in wav.channels)
      Float64List.fromList(
        EqChain.peaking(
          freqsHz: freqsHz,
          gainsDb: gainsDb,
          sampleRate: wav.samplesPerSecond,
          q: q,
        ).processBlock(channel.toList()).map((s) => s * preampLin).toList(),
      ),
  ];
  return Wav(outChannels, wav.samplesPerSecond, wav.format);
}

/// Convenience for mono sample lists (tests, demos).
List<double> renderEqMono(
  List<double> samples, {
    required List<double> freqsHz,
    required List<double> gainsDb,
    required int sampleRate,
    double preampDb = 0,
    double q = 1.0,
  }) {
  final preampLin = math.pow(10, preampDb / 20).toDouble();
  final out = EqChain.peaking(
    freqsHz: freqsHz,
    gainsDb: gainsDb,
    sampleRate: sampleRate,
    q: q,
  ).processBlock(samples);
  if (preampLin == 1.0) return out;
  return out.map((s) => s * preampLin).toList();
}
