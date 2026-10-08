import 'package:flutter_test/flutter_test.dart';

import 'package:audio_eq/features/eq/data/apo_preset.dart';

const sampleApo = '''
# AutoEQ-style headphone correction
Preamp: -5.5 dB
Filter 1: ON PK Fc 60 Hz Gain 4.0 dB Q 1.00
Filter 2: ON PK Fc 230 Hz Gain -1.5 dB Q 1.20
Filter 3: OFF PK Fc 910 Hz Gain 9.9 dB Q 1.00
Filter 4: ON LS Fc 100 Hz Gain 2.0 dB
Filter 5: ON HS Fc 10000 Hz Gain -2.5 dB Q 0.90
; a comment line
''';

const appBands = [60.0, 230.0, 910.0, 3600.0, 14000.0];

void main() {
  test('parses preamp, filters, skips OFF + comments', () {
    final preset = parseApoPreset(sampleApo, name: 'Test HP');
    expect(preset.name, 'Test HP');
    expect(preset.preampDb, -5.5);
    // OFF filter excluded → 4 filters.
    expect(preset.filters.length, 4);
    expect(preset.filters[0].frequencyHz, 60);
    expect(preset.filters[0].gainDb, 4.0);
    expect(preset.filters[0].q, 1.0);
    expect(preset.filters[2].type, ApoFilterType.lowShelf);
    expect(preset.filters[2].q, 1.0); // defaulted
    expect(preset.filters[3].type, ApoFilterType.highShelf);
  });

  test('toGains maps each filter to nearest band + preamp', () {
    final preset = parseApoPreset(sampleApo);
    final gains = preset.toGains(appBands);
    // preamp everywhere; 60Hz PK -> band 0; 230 PK -> band 1;
    // 100Hz LS nearest is 60 (log-distance); 10k HS nearest is 14k.
    expect(gains[0], closeTo(-5.5 + 4.0 + 2.0, 1e-9));
    expect(gains[1], closeTo(-5.5 - 1.5, 1e-9));
    expect(gains[2], closeTo(-5.5, 1e-9));
    expect(gains[3], closeTo(-5.5, 1e-9));
    expect(gains[4], closeTo(-5.5 - 2.5, 1e-9));
  });

  test('toGains without preamp leaves headroom for the engine preamp', () {
    final preset = parseApoPreset(sampleApo);
    final gains = preset.toGains(appBands, includePreamp: false);
    expect(gains[0], closeTo(4.0 + 2.0, 1e-9));
    expect(gains[1], closeTo(-1.5, 1e-9));
    expect(gains[4], closeTo(-2.5, 1e-9));
    expect(preset.preampDb, -5.5);
  });

  test('export round-trips through the parser', () {
    const gains = [6.0, 4.0, 0.0, -1.5, 3.0];
    const preset = ApoPreset(name: 'RoundTrip');
    final text = preset.toApoText(appBands, gains);
    final reparsed = parseApoPreset(text, name: 'RoundTrip');
    expect(reparsed.filters.length, 5);
    expect(reparsed.toGains(appBands), gains);
  });

  test('unsupported ON filter type throws', () {
    expect(
      () => parseApoPreset('Filter 1: ON LP Fc 500 Hz Gain 3 dB'),
      throwsFormatException,
    );
  });

  test('empty file yields empty preset, not an error', () {
    final preset = parseApoPreset('# nothing here\n');
    expect(preset.filters, isEmpty);
    expect(preset.preampDb, 0);
  });
}
