import 'dart:math' as math;

/// Second-order IIR filter (biquad) using the RBJ Audio EQ Cookbook formulas.
///
/// See https://www.w3.org/TR/audio-eq-cookbook/ — the same math behind most
/// parametric EQs worldwide (Equalizer APO, EasyEffects, CamillaDSP).
///
/// Coefficients are normalized (a0 = 1). Instances are stateful (Direct Form
/// I); use one instance per channel, or [EqChain] which handles that.
class Biquad {
  Biquad._({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  final double b0, b1, b2, a1, a2;

  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  /// Peaking (bell) band: boosts/cuts around [freqHz] with bandwidth set by
  /// [q]. Gain 0 dB is bit-transparent (up to float rounding).
  factory Biquad.peaking({
    required double freqHz,
    required double q,
    required double gainDb,
    required int sampleRate,
  }) {
    final a = math.pow(10, gainDb / 40).toDouble();
    final w0 = 2 * math.pi * freqHz / sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final cosW0 = math.cos(w0);
    return Biquad._(
      b0: 1 + alpha * a,
      b1: -2 * cosW0,
      b2: 1 - alpha * a,
      a1: -2 * cosW0,
      a2: 1 - alpha / a,
    )._normalized(1 + alpha / a);
  }

  /// Low shelf: boosts/cuts everything below [freqHz]. [s] is shelf slope
  /// (1 = gentle, higher = steeper), default 1.
  factory Biquad.lowShelf({
    required double freqHz,
    required double gainDb,
    required int sampleRate,
    double s = 1,
  }) {
    final a = math.pow(10, gainDb / 40).toDouble();
    final w0 = 2 * math.pi * freqHz / sampleRate;
    final alpha = math.sin(w0) / 2 * math.sqrt((a + 1 / a) * (1 / s - 1) + 2);
    final cosW0 = math.cos(w0);
    final sqrtA = math.sqrt(a);
    return Biquad._(
      b0: a * ((a + 1) - (a - 1) * cosW0 + 2 * sqrtA * alpha),
      b1: 2 * a * ((a - 1) - (a + 1) * cosW0),
      b2: a * ((a + 1) - (a - 1) * cosW0 - 2 * sqrtA * alpha),
      a1: -2 * ((a - 1) + (a + 1) * cosW0),
      a2: (a + 1) + (a - 1) * cosW0 - 2 * sqrtA * alpha,
    )._normalized((a + 1) + (a - 1) * cosW0 + 2 * sqrtA * alpha);
  }

  /// High shelf: boosts/cuts everything above [freqHz].
  factory Biquad.highShelf({
    required double freqHz,
    required double gainDb,
    required int sampleRate,
    double s = 1,
  }) {
    final a = math.pow(10, gainDb / 40).toDouble();
    final w0 = 2 * math.pi * freqHz / sampleRate;
    final alpha = math.sin(w0) / 2 * math.sqrt((a + 1 / a) * (1 / s - 1) + 2);
    final cosW0 = math.cos(w0);
    final sqrtA = math.sqrt(a);
    return Biquad._(
      b0: a * ((a + 1) + (a - 1) * cosW0 + 2 * sqrtA * alpha),
      b1: -2 * a * ((a - 1) + (a + 1) * cosW0),
      b2: a * ((a + 1) + (a - 1) * cosW0 - 2 * sqrtA * alpha),
      a1: 2 * ((a - 1) - (a + 1) * cosW0),
      a2: (a + 1) - (a - 1) * cosW0 - 2 * sqrtA * alpha,
    )._normalized((a + 1) - (a - 1) * cosW0 + 2 * sqrtA * alpha);
  }

  Biquad _normalized(double a0) => Biquad._(
        b0: b0 / a0,
        b1: b1 / a0,
        b2: b2 / a0,
        a1: a1 / a0,
        a2: a2 / a0,
      );

  /// Process one sample in [-1, 1].
  double process(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }

  /// Process a block, returning a new list.
  List<double> processBlock(List<double> input) =>
      input.map(process).toList();

  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0;
  }

  /// Steady-state magnitude response |H(f)| at [freqHz] (linear, not dB).
  /// Used by the EQ curve widget and tests — no audio needed.
  double magnitudeAt(double freqHz, int sampleRate) {
    final w = 2 * math.pi * freqHz / sampleRate;
    final cosW = math.cos(w), cos2W = math.cos(2 * w);
    final sinW = math.sin(w), sin2W = math.sin(2 * w);
    final numRe = b0 + b1 * cosW + b2 * cos2W;
    final numIm = -(b1 * sinW + b2 * sin2W);
    final denRe = 1 + a1 * cosW + a2 * cos2W;
    final denIm = -(a1 * sinW + a2 * sin2W);
    return math.sqrt(numRe * numRe + numIm * numIm) /
        math.sqrt(denRe * denRe + denIm * denIm);
  }
}

/// A series chain of peaking bands — one [Biquad] per band, per channel.
///
/// Matches the app's 5-band model: [freqsHz] center frequencies,
/// [gainsDb] per-band gains, shared [q].
class EqChain {
  EqChain.peaking({
    required this.freqsHz,
    required this.gainsDb,
    required this.sampleRate,
    this.q = 1.0,
  }) : assert(freqsHz.length == gainsDb.length);

  final List<double> freqsHz;
  final List<double> gainsDb;
  final int sampleRate;
  final double q;

  late final List<Biquad> _bands = [
    for (var i = 0; i < freqsHz.length; i++)
      Biquad.peaking(
        freqHz: freqsHz[i],
        q: q,
        gainDb: gainsDb[i],
        sampleRate: sampleRate,
      ),
  ];

  List<double> processBlock(List<double> input) {
    var out = input;
    for (final band in _bands) {
      out = band.processBlock(out);
    }
    return out;
  }

  void reset() {
    for (final band in _bands) {
      band.reset();
    }
  }

  /// Combined magnitude response across all bands (linear).
  double magnitudeAt(double freqHz) {
    var mag = 1.0;
    for (var i = 0; i < freqsHz.length; i++) {
      mag *= Biquad.peaking(
        freqHz: freqsHz[i],
        q: q,
        gainDb: gainsDb[i],
        sampleRate: sampleRate,
      ).magnitudeAt(freqHz, sampleRate);
    }
    return mag;
  }
}
