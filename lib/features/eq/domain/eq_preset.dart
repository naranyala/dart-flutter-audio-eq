import 'package:flutter/foundation.dart';

/// A named set of band gains, e.g. "Flat", "Bass Boost".
@immutable
class EqPreset {
  const EqPreset({required this.name, required this.gainsDb});

  final String name;
  final List<double> gainsDb;

  Map<String, Object?> toJson() => {'name': name, 'gainsDb': gainsDb};

  factory EqPreset.fromJson(Map<String, Object?> json) => EqPreset(
        name: json['name'] as String,
        gainsDb: (json['gainsDb'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  /// Built-in library: tone fixes, voice, genres, listening scenarios.
  /// Gains are 5-band approximations (60 / 230 / 910 / 3.6k / 14k Hz) of the
  /// canonical graphic-EQ curves for each use case. Per-headphone measured
  /// corrections belong in the AutoEQ bundle (see TODOS), not here.
  static List<EqPreset> defaults(int bandCount) => [
        EqPreset(name: 'Flat', gainsDb: List.filled(bandCount, 0)),
        // Tone fixes.
        EqPreset(name: 'Bass Boost', gainsDb: _fit([6, 4, 0, 0, 0], bandCount)),
        EqPreset(name: 'Bass Cut', gainsDb: _fit([-5, -3, 0, 0, 0], bandCount)),
        EqPreset(
            name: 'Treble Boost', gainsDb: _fit([0, 0, 0, 4, 6], bandCount)),
        EqPreset(name: 'Warm', gainsDb: _fit([1, 1, 0, -3, -5], bandCount)),
        EqPreset(name: 'Loudness', gainsDb: _fit([5, 3, 0, 1, 4], bandCount)),
        // Voice.
        EqPreset(name: 'Vocal', gainsDb: _fit([-2, 0, 3, 3, 1], bandCount)),
        EqPreset(name: 'Podcast', gainsDb: _fit([-5, -2, 2, 4, 2], bandCount)),
        // Genres.
        EqPreset(name: 'Rock', gainsDb: _fit([5, 3, -2, 2, 5], bandCount)),
        EqPreset(name: 'Pop', gainsDb: _fit([4, 2, 0, 2, 4], bandCount)),
        EqPreset(name: 'Hip-Hop', gainsDb: _fit([7, 4, -1, 1, 5], bandCount)),
        EqPreset(
            name: 'Electronic', gainsDb: _fit([6, 3, 0, 2, 5], bandCount)),
        EqPreset(name: 'Jazz', gainsDb: _fit([4, 3, 1, 2, 3], bandCount)),
        EqPreset(
            name: 'Classical', gainsDb: _fit([3, 1, 0, 1, 3], bandCount)),
        EqPreset(name: 'Metal', gainsDb: _fit([6, 3, -4, 3, 6], bandCount)),
        // Scenarios.
        EqPreset(
            name: 'Late Night', gainsDb: _fit([-3, -1, 2, 3, 2], bandCount)),
        EqPreset(name: 'Gaming', gainsDb: _fit([-2, 0, 4, 5, 3], bandCount)),
      ];

  static List<double> _fit(List<double> src, int n) {
    if (src.length == n) return List.of(src);
    if (src.length > n) return src.sublist(0, n);
    return [...src, ...List.filled(n - src.length, 0)];
  }
}
