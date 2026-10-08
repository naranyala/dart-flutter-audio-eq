import 'dart:math' as math;

import 'package:fft/fft.dart';

/// Small FFT helpers for the spectrum analyzer UI (P1).
///
/// Tested here with synthetic tones so the future live path
/// (Android `Visualizer` API / Linux capture) reuses proven code.
class Spectrum {
  /// Peak frequency in Hz of [samples] rendered at [sampleRate].
  ///
  /// [samples] is truncated/padded to the FFT size (must be a power of 2).
  static double peakFrequency(
    List<double> samples,
    int sampleRate, {
    int fftSize = 4096,
  }) {
    final mags = magnitudeSpectrum(samples, fftSize: fftSize);
    var peakBin = 1;
    for (var i = 2; i < mags.length; i++) {
      if (mags[i] > mags[peakBin]) peakBin = i;
    }
    return peakBin * sampleRate / fftSize;
  }

  /// Single-sided magnitude spectrum (bins 0..fftSize/2).
  static List<double> magnitudeSpectrum(
    List<double> samples, {
    int fftSize = 4096,
  }) {
    final windowed = List<double>.generate(fftSize, (i) {
      final x = i < samples.length ? samples[i] : 0.0;
      // Hann window reduces leakage for non-bin-centered tones.
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / fftSize));
      return x * w;
    });
    final spectrum = FFT.Transform(windowed);
    return List<double>.generate(
      fftSize ~/ 2,
      (i) => spectrum[i].abs(),
    );
  }
}
