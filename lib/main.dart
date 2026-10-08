import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/eq/data/mock_eq_engine.dart';
import 'features/eq/domain/eq_engine.dart';

/// Global provider for the [EqEngine].
///
/// Starts as [MockEqEngine] (works everywhere: Linux + Android UI).
/// Swap with native implementations later:
///   - Android: platform-channel wrapper around android.media.audiofx.Equalizer
///   - Linux: PipeWire / PulseAudio / GStreamer element
///   - (future) macOS: AudioUnit, Windows: APO / WASAPI DSP
final eqEngineProvider = Provider<EqEngine>((ref) {
  final engine = MockEqEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AudioEqApp()));
}
