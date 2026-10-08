import 'package:audio_eq/features/eq/domain/eq_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EqBand clamps are respected by copyWith callers', () {
    const band = EqBand(frequencyHz: 1000, gainDb: 0);
    expect(band.copyWith(gainDb: 5).gainDb, 5);
    expect(EqBand.minGainDb, -12);
    expect(EqBand.maxGainDb, 12);
  });

  test('EqBand json round-trip', () {
    const band = EqBand(frequencyHz: 230, gainDb: -3.5, q: 1.2);
    final restored = EqBand.fromJson(band.toJson());
    expect(restored.frequencyHz, 230);
    expect(restored.gainDb, -3.5);
    expect(restored.q, 1.2);
  });
}
