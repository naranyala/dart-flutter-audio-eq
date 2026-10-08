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

  static List<EqPreset> defaults(int bandCount) => [
        EqPreset(name: 'Flat', gainsDb: List.filled(bandCount, 0)),
        EqPreset(name: 'Bass Boost', gainsDb: _fit([6, 4, 0, 0, 0], bandCount)),
        EqPreset(name: 'Vocal', gainsDb: _fit([-2, 0, 3, 3, 1], bandCount)),
        EqPreset(name: 'Treble', gainsDb: _fit([0, 0, 0, 4, 6], bandCount)),
      ];

  static List<double> _fit(List<double> src, int n) {
    if (src.length == n) return List.of(src);
    if (src.length > n) return src.sublist(0, n);
    return [...src, ...List.filled(n - src.length, 0)];
  }
}
