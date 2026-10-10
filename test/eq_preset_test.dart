import 'package:flutter_test/flutter_test.dart';

import 'package:audio_eq/features/eq/domain/eq_preset.dart';

void main() {
  test('built-in library is rich and valid', () {
    final presets = EqPreset.defaults(5);

    // Flat first, then tone fixes / voice / genres / scenarios.
    expect(presets.first.name, 'Flat');
    expect(presets.first.gainsDb, everyElement(0));
    expect(presets.length, greaterThanOrEqualTo(12));

    final names = presets.map((p) => p.name).toList();
    expect(names.toSet().length, names.length); // unique names
    for (final name in [
      'Bass Boost',
      'Bass Cut',
      'Treble Boost',
      'Warm',
      'Loudness',
      'Vocal',
      'Podcast',
      'Rock',
      'Pop',
      'Hip-Hop',
      'Electronic',
      'Jazz',
      'Classical',
      'Metal',
      'Late Night',
      'Gaming',
    ]) {
      expect(names, contains(name));
    }

    for (final preset in presets) {
      expect(preset.gainsDb.length, 5);
      for (final gain in preset.gainsDb) {
        expect(gain, inInclusiveRange(-12, 12));
      }
    }
  });

  test('defaults adapt to other band counts', () {
    expect(EqPreset.defaults(3).first.gainsDb.length, 3);
    expect(EqPreset.defaults(10).first.gainsDb.length, 10);
  });

  test('preset json round-trip', () {
    const preset = EqPreset(name: 'Test', gainsDb: [1, 2, 3]);
    final restored = EqPreset.fromJson(preset.toJson());
    expect(restored.name, 'Test');
    expect(restored.gainsDb, [1.0, 2.0, 3.0]);
  });
}
