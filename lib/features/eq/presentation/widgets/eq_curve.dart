import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../dsp/biquad.dart';

/// Static EQ response curve: combined magnitude of all bands + preamp.
///
/// Pure math from the tested [EqChain.magnitudeAt] — no audio, no
/// permissions, no native code. X axis is logarithmic (20 Hz – 20 kHz),
/// Y axis is dB over [dbRange].
class EqCurveWidget extends StatelessWidget {
  const EqCurveWidget({
    super.key,
    required this.freqsHz,
    required this.gainsDb,
    this.preampDb = 0,
    this.q = 1.0,
    this.height = 148,
    this.dbRange = 15,
  });

  final List<double> freqsHz;
  final List<double> gainsDb;
  final double preampDb;
  final double q;
  final double height;
  final double dbRange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _EqCurvePainter(
          freqsHz: freqsHz,
          gainsDb: gainsDb,
          preampDb: preampDb,
          q: q,
          dbRange: dbRange,
          lineColor: scheme.primary,
          gridColor: scheme.outlineVariant,
          fillColor: scheme.primaryContainer.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({
    required this.freqsHz,
    required this.gainsDb,
    required this.preampDb,
    required this.q,
    required this.dbRange,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
  });

  final List<double> freqsHz;
  final List<double> gainsDb;
  final double preampDb;
  final double q;
  final double dbRange;
  final Color lineColor;
  final Color gridColor;
  final Color fillColor;

  static const _minF = 20.0;
  static const _maxF = 20000.0;
  static const _points = 120;

  double _dbAt(double f, int sampleRate) {
    var mag = 1.0;
    for (var i = 0; i < freqsHz.length; i++) {
      mag *= Biquad.peaking(
        freqHz: freqsHz[i],
        q: q,
        gainDb: gainsDb[i],
        sampleRate: sampleRate,
      ).magnitudeAt(f, sampleRate);
    }
    mag *= math.pow(10, preampDb / 20).toDouble();
    return 20 * (math.log(mag) / math.ln10);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const sampleRate = 48000;
    final logMin = math.log(_minF) / math.ln10;
    final logMax = math.log(_maxF) / math.ln10;
    double xOf(double f) =>
        (math.log(f) / math.ln10 - logMin) / (logMax - logMin) * size.width;
    double yOf(double db) =>
        size.height / 2 - (db.clamp(-dbRange, dbRange) / dbRange) * (size.height / 2 - 4);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      final y = yOf(db);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        grid..strokeWidth = db == 0 ? 1.5 : 1.0,
      );
    }
    for (final f in [50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0]) {
      canvas.drawLine(
        Offset(xOf(f), 0),
        Offset(xOf(f), size.height),
        grid..strokeWidth = 1.0,
      );
    }

    final path = Path();
    for (var i = 0; i <= _points; i++) {
      final f = math.pow(10, logMin + (logMax - logMin) * i / _points)
          .toDouble();
      final p = Offset(xOf(f), yOf(_dbAt(f, sampleRate)));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, yOf(0))
      ..lineTo(0, yOf(0))
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Band center markers.
    for (final f in freqsHz) {
      if (f < _minF || f > _maxF) continue;
      final x = xOf(f);
      canvas.drawCircle(
        Offset(x, yOf(_dbAt(f, sampleRate))),
        3.5,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) =>
      old.freqsHz != freqsHz ||
      old.gainsDb != gainsDb ||
      old.preampDb != preampDb ||
      old.q != q ||
      old.dbRange != dbRange;
}
