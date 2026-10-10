import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wav/wav.dart';

import 'package:audio_eq/features/player/audition_source.dart';

const sampleRate = 44100;
const freqs = [60.0, 230.0, 910.0, 3600.0, 14000.0];

Wav demoTone() {
  final n = sampleRate; // 1 s: 110 Hz + 1 kHz + 8 kHz mix
  final ch = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    ch[i] = 0.2 * math.sin(2 * math.pi * 110 * t) +
        0.2 * math.sin(2 * math.pi * 1000 * t) +
        0.1 * math.sin(2 * math.pi * 8000 * t);
  }
  return Wav([ch], sampleRate);
}

void main() {
  test('bypass returns the untouched base (true bypass)', () {
    final base = demoTone();
    final out = renderAudition(
      base: base,
      freqsHz: freqs,
      gainsDb: const [6, 6, 6, 6, 6],
      preampDb: -6,
      enabled: false,
    );
    expect(out.write(), base.write());
  });

  test('enabled render differs audibly from base, same shape', () {
    final base = demoTone();
    final out = renderAudition(
      base: base,
      freqsHz: freqs,
      gainsDb: const [6, 0, 0, 0, 6],
      preampDb: 0,
      enabled: true,
    );
    expect(out.samplesPerSecond, sampleRate);
    expect(out.channels.length, 1);
    expect(out.channels[0].length, base.channels[0].length);
    expect(out.write(), isNot(equals(base.write())));
  });

  test('flat enabled render is transparent', () {
    final base = demoTone();
    final out = renderAudition(
      base: base,
      freqsHz: freqs,
      gainsDb: const [0, 0, 0, 0, 0],
      preampDb: 0,
      enabled: true,
    );
    // Float rounding only — byte-compare would be too strict.
    final a = out.channels[0];
    final b = base.channels[0];
    var maxDiff = 0.0;
    for (var i = a.length ~/ 2; i < a.length; i++) {
      maxDiff = math.max(maxDiff, (a[i] - b[i]).abs());
    }
    expect(maxDiff, lessThan(1e-9));
  });
}
