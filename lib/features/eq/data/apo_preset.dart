/// Equalizer APO `.txt` preset format: parse + serialize.
///
/// The APO text format is the closest thing the EQ world has to a lingua
/// franca (Equalizer APO, Peace, Neon Equalizer, AutoEQ exports, Resonance
/// all read it). Supporting it gives this app an instant preset library.
///
/// Supported subset (v1):
///   Preamp: -6 dB
///   Filter 1: ON PK Fc 1000 Hz Gain 3.5 dB Q 1.00
///   Filter 2: ON LS Fc 100 Hz Gain 2.0 dB
///   Filter 3: ON HS Fc 10000 Hz Gain -1.5 dB
///
/// - `ON`/`OFF`: OFF lines are skipped.
/// - `PK` (peaking), `LS` (low shelf), `HS` (high shelf). Other ON filter
///   types throw [FormatException] so callers can surface "unsupported".
/// - `#` / `;` comments and blank lines are ignored.
/// - Q is optional (defaults to 1.0).
library;

import 'dart:math' as math;

enum ApoFilterType { peak, lowShelf, highShelf }

class ApoFilter {
  const ApoFilter({
    required this.type,
    required this.frequencyHz,
    required this.gainDb,
    this.q = 1.0,
  });

  final ApoFilterType type;
  final double frequencyHz;
  final double gainDb;
  final double q;
}

class ApoPreset {
  const ApoPreset({
    required this.name,
    this.preampDb = 0,
    this.filters = const [],
  });

  final String name;
  final double preampDb;
  final List<ApoFilter> filters;

  /// Map this preset onto [targetFreqs] band gains.
  ///
  /// Approximation (documented, v1): each filter contributes its full gain to
  /// the single nearest target band. With [includePreamp] (default) the
  /// preamp is added on top of every band (legacy behavior); pass false and
  /// apply [preampDb] separately via the engine's preamp (preferred — avoids
  /// wasting band headroom and matches AutoEQ intent).
  List<double> toGains(List<double> targetFreqs, {bool includePreamp = true}) {
    final gains = List<double>.filled(
      targetFreqs.length,
      includePreamp ? preampDb : 0,
    );
    for (final f in filters) {
      var nearest = 0;
      var best = double.infinity;
      final target = math.log(f.frequencyHz) / math.ln10;
      for (var i = 0; i < targetFreqs.length; i++) {
        final d =
            (math.log(targetFreqs[i]) / math.ln10 - target).abs();
        if (d < best) {
          best = d;
          nearest = i;
        }
      }
      gains[nearest] += f.gainDb;
    }
    return gains;
  }

  /// Serialize back to APO `.txt` (one PK line per band + preamp).
  String toApoText(List<double> bandFreqs, List<double> gainsDb) {
    final buf = StringBuffer()
      ..writeln('# Exported by audio_eq ($name)');
    if (preampDb != 0) {
      buf.writeln('Preamp: ${_fmt(preampDb)} dB');
    }
    for (var i = 0; i < bandFreqs.length; i++) {
      buf.writeln(
        'Filter ${i + 1}: ON PK Fc ${_fmt(bandFreqs[i])} Hz '
        'Gain ${_fmt(gainsDb[i])} dB Q 1.00',
      );
    }
    return buf.toString();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Parse APO `.txt` [text] into an [ApoPreset] named [name].
ApoPreset parseApoPreset(String text, {String name = 'Imported'}) {
  var preampDb = 0.0;
  final filters = <ApoFilter>[];

  final preampRe = RegExp(
    r'^\s*preamp\s*:\s*([+-]?\d+(?:\.\d+)?)\s*dB',
    caseSensitive: false,
  );
  final filterRe = RegExp(
    r'^\s*filter\s+\d+\s*:\s*(ON|OFF)\s+(PK|LS|HS)\s+'
    r'Fc\s+(\d+(?:\.\d+)?)\s*Hz\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s*dB'
    r'(?:\s+Q\s+(\d+(?:\.\d+)?))?',
    caseSensitive: false,
  );
  final unsupportedRe = RegExp(
    r'^\s*filter\s+\d+\s*:\s*ON\s+([A-Z]+)',
    caseSensitive: false,
  );

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
      continue;
    }
    final preamp = preampRe.firstMatch(line);
    if (preamp != null) {
      preampDb = double.parse(preamp.group(1)!);
      continue;
    }
    final filter = filterRe.firstMatch(line);
    if (filter != null) {
      if (filter.group(1)!.toUpperCase() != 'ON') continue;
      final type = switch (filter.group(2)!.toUpperCase()) {
        'PK' => ApoFilterType.peak,
        'LS' => ApoFilterType.lowShelf,
        'HS' => ApoFilterType.highShelf,
        _ => throw FormatException('Unreachable filter type: $line'),
      };
      filters.add(
        ApoFilter(
          type: type,
          frequencyHz: double.parse(filter.group(3)!),
          gainDb: double.parse(filter.group(4)!),
          q: filter.group(5) != null ? double.parse(filter.group(5)!) : 1.0,
        ),
      );
      continue;
    }
    final unsupported = unsupportedRe.firstMatch(line);
    if (unsupported != null) {
      throw FormatException(
        'Unsupported APO filter type "${unsupported.group(1)}": $line',
      );
    }
    // Unknown lines (GraphicEQ, Device, comments without markers…) are
    // ignored in v1 rather than failing the whole import.
  }

  return ApoPreset(name: name, preampDb: preampDb, filters: filters);
}
