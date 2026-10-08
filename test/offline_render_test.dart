import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wav/wav.dart';

import 'package:audio_eq/features/dsp/offline_render.dart';

const sampleRate = 44100;

List<double> sine(double freqHz, {int n = sampleRate}) =>
    List.generate(n, (i) => 0.5 * math.sin(2 * math.pi * freqHz * i / sampleRate));

double rms(List<double> x) {
  final tail = x.sublist(x.length ~/ 2);
  var sum = 0.0;
  for (final v in tail) {
    sum += v * v;
  }
  return math.sqrt(sum / tail.length);
}

void main() {
  test('flat render is transparent and preserves wav metadata', () {
    final wav = Wav(
      [Float64List.fromList(sine(1000)), Float64List.fromList(sine(500))],
      sampleRate,
    );
    final out = renderEqOnWav(
      wav,
      freqsHz: const [60, 230, 910, 3600, 14000],
      gainsDb: const [0, 0, 0, 0, 0],
    );
    expect(out.samplesPerSecond, sampleRate);
    expect(out.channels.length, 2);
    expect(rms(out.channels[0].toList()) / rms(sine(1000)), closeTo(1, 1e-6));
    // Serializes to a real RIFF file.
    final bytes = out.write();
    expect(bytes.length, greaterThan(44));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  });

  test('boosted render is measurably louder at center frequency', () {
    final wav = Wav([Float64List.fromList(sine(910))], sampleRate);
    final out = renderEqOnWav(
      wav,
      freqsHz: const [60, 230, 910, 3600, 14000],
      gainsDb: const [0, 0, 6, 0, 0],
    );
    expect(
      rms(out.channels[0].toList()) / rms(sine(910)),
      closeTo(2.0, 0.15),
    );
  });

  test('preamp applies flat gain without touching band gains', () {
    final boosted = renderEqMono(
      sine(910),
      freqsHz: const [910],
      gainsDb: const [0],
      preampDb: 6,
      sampleRate: sampleRate,
    );
    expect(rms(boosted) / rms(sine(910)), closeTo(2.0, 0.05));
  });

  test('channels are processed independently', () {
    final boosted = renderEqMono(
      sine(910),
      freqsHz: const [910],
      gainsDb: const [6],
      sampleRate: sampleRate,
    );
    final flat = renderEqMono(
      sine(910),
      freqsHz: const [910],
      gainsDb: const [0],
      sampleRate: sampleRate,
    );
    expect(rms(boosted) / rms(flat), closeTo(2.0, 0.15));
  });
}
