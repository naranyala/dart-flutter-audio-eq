import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

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
  // Registers the mpv backend for just_audio on Linux/Windows.
  // No-op on Android/iOS/macOS by default — safe to call everywhere.
  // Throws when system libmpv is missing: survive it, the player provider
  // degrades to its error branch instead of killing the whole app.
  try {
    JustAudioMediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[main] mpv backend unavailable, demo playback disabled: $e');
  }
  runApp(const ProviderScope(child: AudioEqApp()));
}
