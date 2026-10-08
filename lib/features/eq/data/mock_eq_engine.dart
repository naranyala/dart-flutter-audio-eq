import 'package:flutter/foundation.dart';

import '../domain/eq_engine.dart';

/// In-memory engine so the UI runs on Linux + Android today.
///
/// Replace per-platform with real DSP:
///   TODO(android): MethodChannel -> android.media.audiofx.Equalizer,
///     attach to just_audio session id via AudioSession.
///   TODO(linux): talk to PipeWire/Pulse or insert a GStreamer
///     equalizer element; see README "Linux DSP" section.
///   TODO(macos, windows): AudioUnit / WASAPI DSP stubs.
class MockEqEngine implements EqEngine {
  MockEqEngine({List<double>? frequenciesHz})
      : frequenciesHz = frequenciesHz ??
            const [60, 230, 910, 3600, 14000];

  @override
  final List<double> frequenciesHz;

  final ValueNotifier<bool> enabled = ValueNotifier(true);
  final ValueNotifier<List<double>> gainsDb =
      ValueNotifier(const [0, 0, 0, 0, 0]);
  final ValueNotifier<double> preampDb = ValueNotifier(0);

  @override
  Future<void> init() async {
    debugPrint('[MockEqEngine] init (${frequenciesHz.length} bands)');
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    debugPrint('[MockEqEngine] enabled=$value');
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    final clamped = gainDb.clamp(-12.0, 12.0);
    final next = List<double>.of(gainsDb.value);
    next[bandIndex] = clamped;
    gainsDb.value = next;
    debugPrint('[MockEqEngine] band $bandIndex -> ${clamped.toStringAsFixed(1)} dB');
  }

  @override
  Future<void> setPreamp(double value) async {
    preampDb.value =
        value.clamp(EqEngine.minPreampDb, EqEngine.maxPreampDb);
    debugPrint('[MockEqEngine] preamp -> ${preampDb.value.toStringAsFixed(1)} dB');
  }

  @override
  Future<void> dispose() async {
    enabled.dispose();
    gainsDb.dispose();
    preampDb.dispose();
  }
}
