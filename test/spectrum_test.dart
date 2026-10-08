import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:audio_eq/features/dsp/spectrum.dart';

const sampleRate = 44100;

List<double> sine(double freqHz, {int n = 4096}) =>
    List.generate(n, (i) => 0.5 * math.sin(2 * math.pi * freqHz * i / sampleRate));

void main() {
  test('finds 1 kHz tone', () {
    expect(Spectrum.peakFrequency(sine(1000), sampleRate), closeTo(1000, 15));
  });

  test('finds 440 Hz tone', () {
    expect(Spectrum.peakFrequency(sine(440), sampleRate), closeTo(440, 15));
  });

  test('magnitude spectrum peaks above the noise floor', () {
    final mags = Spectrum.magnitudeSpectrum(sine(1000));
    final peak = mags.reduce(math.max);
    final mean = mags.reduce((a, b) => a + b) / mags.length;
    expect(peak / mean, greaterThan(10));
  });
}
