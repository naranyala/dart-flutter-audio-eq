import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:audio_eq/features/dsp/biquad.dart';

const sampleRate = 44100;

/// 1-second sine at [freqHz], amplitude 0.5.
List<double> sine(double freqHz, {double seconds = 1}) {
  final n = (sampleRate * seconds).round();
  return List.generate(
    n,
    (i) => 0.5 * math.sin(2 * math.pi * freqHz * i / sampleRate),
  );
}

/// RMS of the second half (skips filter transient).
double rms(List<double> x) {
  final tail = x.sublist(x.length ~/ 2);
  var sum = 0.0;
  for (final v in tail) {
    sum += v * v;
  }
  return math.sqrt(sum / tail.length);
}

void main() {
  test('flat chain is transparent', () {
    final chain = EqChain.peaking(
      freqsHz: const [60, 230, 910, 3600, 14000],
      gainsDb: const [0, 0, 0, 0, 0],
      sampleRate: sampleRate,
    );
    final input = sine(1000);
    final out = chain.processBlock(input);
    final ratio = rms(out) / rms(input);
    expect(ratio, closeTo(1.0, 1e-6));
  });

  test('+6 dB peaking doubles amplitude at center frequency', () {
    final chain = EqChain.peaking(
      freqsHz: const [1000],
      gainsDb: const [6],
      sampleRate: sampleRate,
    );
    final ratio = rms(chain.processBlock(sine(1000))) / rms(sine(1000));
    expect(ratio, closeTo(2.0, 0.15));
  });

  test('-6 dB peaking halves amplitude at center frequency', () {
    final chain = EqChain.peaking(
      freqsHz: const [1000],
      gainsDb: const [-6],
      sampleRate: sampleRate,
    );
    final ratio = rms(chain.processBlock(sine(1000))) / rms(sine(1000));
    expect(ratio, closeTo(0.5, 0.05));
  });

  test('peaking is selective: far-away tone nearly untouched', () {
    final chain = EqChain.peaking(
      freqsHz: const [1000],
      gainsDb: const [6],
      sampleRate: sampleRate,
    );
    final ratio = rms(chain.processBlock(sine(100))) / rms(sine(100));
    expect(ratio, lessThan(1.2));
  });

  test('magnitudeAt agrees with time-domain gain', () {
    final band = Biquad.peaking(
      freqHz: 1000,
      q: 1,
      gainDb: 6,
      sampleRate: sampleRate,
    );
    expect(band.magnitudeAt(1000, sampleRate), closeTo(2.0, 0.01));
    expect(band.magnitudeAt(100, sampleRate), lessThan(1.2));
  });

  test('low shelf boosts lows, spares highs', () {
    final shelf = Biquad.lowShelf(
      freqHz: 200,
      gainDb: 6,
      sampleRate: sampleRate,
    );
    final lowRatio = rms(shelf.processBlock(sine(50))) / rms(sine(50));
    shelf.reset();
    final highRatio = rms(shelf.processBlock(sine(10000))) / rms(sine(10000));
    expect(lowRatio, greaterThan(1.5));
    expect(highRatio, lessThan(1.2));
  });

  test('high shelf boosts highs, spares lows', () {
    final shelf = Biquad.highShelf(
      freqHz: 8000,
      gainDb: 6,
      sampleRate: sampleRate,
    );
    final highRatio = rms(shelf.processBlock(sine(15000))) / rms(sine(15000));
    shelf.reset();
    final lowRatio = rms(shelf.processBlock(sine(100))) / rms(sine(100));
    expect(highRatio, greaterThan(1.5));
    expect(lowRatio, lessThan(1.2));
  });
}
