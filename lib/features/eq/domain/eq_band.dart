import 'package:flutter/foundation.dart';

/// One parametric/peaking band.
@immutable
class EqBand {
  const EqBand({
    required this.frequencyHz,
    required this.gainDb,
    this.q = 1.0,
  });

  final double frequencyHz;
  final double gainDb;
  final double q;

  static const double minGainDb = -12;
  static const double maxGainDb = 12;

  EqBand copyWith({double? gainDb, double? q}) => EqBand(
        frequencyHz: frequencyHz,
        gainDb: gainDb ?? this.gainDb,
        q: q ?? this.q,
      );

  Map<String, Object?> toJson() => {
        'frequencyHz': frequencyHz,
        'gainDb': gainDb,
        'q': q,
      };

  factory EqBand.fromJson(Map<String, Object?> json) => EqBand(
        frequencyHz: (json['frequencyHz'] as num).toDouble(),
        gainDb: (json['gainDb'] as num).toDouble(),
        q: ((json['q'] as num?) ?? 1.0).toDouble(),
      );
}
