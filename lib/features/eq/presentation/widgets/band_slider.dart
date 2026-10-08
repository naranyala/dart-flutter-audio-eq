import 'package:flutter/material.dart';

import '../../domain/eq_band.dart';

class BandSlider extends StatelessWidget {
  const BandSlider({
    super.key,
    required this.band,
    required this.onChanged,
  });

  final EqBand band;
  final ValueChanged<double> onChanged;

  String get _label {
    final f = band.frequencyHz;
    if (f >= 1000) return '${(f / 1000).toStringAsFixed(f >= 10000 ? 0 : 1)}k';
    return f.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          band.gainDb.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              min: EqBand.minGainDb,
              max: EqBand.maxGainDb,
              divisions: 48,
              value: band.gainDb,
              label: '${band.gainDb.toStringAsFixed(1)} dB',
              onChanged: onChanged,
            ),
          ),
        ),
        Text(_label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
