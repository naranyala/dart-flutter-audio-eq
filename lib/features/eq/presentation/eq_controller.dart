import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';

import '../../../main.dart';
import '../../player/audition_source.dart';
import '../../player/audio_player_service.dart';
import '../data/preset_file_service.dart';
import '../data/preset_repository.dart';
import '../domain/eq_band.dart';
import '../domain/eq_engine.dart';
import '../domain/eq_preset.dart';

@immutable
class EqState {
  const EqState({
    required this.bands,
    required this.enabled,
    required this.presetName,
    required this.presets,
    this.preampDb = 0,
  });

  final List<EqBand> bands;
  final bool enabled;
  final String presetName;
  final List<EqPreset> presets;

  /// Overall gain in dB, range [EqEngine.minPreampDb, EqEngine.maxPreampDb].
  final double preampDb;

  List<double> get gainsDb => bands.map((b) => b.gainDb).toList();

  EqState copyWith({
    List<EqBand>? bands,
    bool? enabled,
    String? presetName,
    List<EqPreset>? presets,
    double? preampDb,
  }) =>
      EqState(
        bands: bands ?? this.bands,
        enabled: enabled ?? this.enabled,
        presetName: presetName ?? this.presetName,
        presets: presets ?? this.presets,
        preampDb: preampDb ?? this.preampDb,
      );
}

final presetRepositoryProvider = FutureProvider<PresetRepository>((ref) async {
  return PresetRepository.load();
});

final eqControllerProvider =
    StateNotifierProvider<EqController, EqState>((ref) {
  final engine = ref.watch(eqEngineProvider);
  return EqController(engine, ref)..init();
});

class EqController extends StateNotifier<EqState> {
  EqController(
    this._engine,
    this._ref, [
    PresetFileService? files,
    Future<Directory> Function()? getTempDir,
    Future<ByteData> Function()? loadDemoBytes,
  ])  : _files = files ?? PresetFileService(),
        _getTempDir = getTempDir ?? getTemporaryDirectory,
        _loadDemoBytes = loadDemoBytes ?? (() => rootBundle.load(demoAsset)),
        super(
          EqState(
            bands: _engine.frequenciesHz
                .map((f) => EqBand(frequencyHz: f, gainDb: 0))
                .toList(),
            enabled: true,
            presetName: 'Flat',
            presets: EqPreset.defaults(_engine.frequenciesHz.length),
          ),
        );

  final EqEngine _engine;
  final Ref _ref;
  final PresetFileService _files;
  final Future<Directory> Function() _getTempDir;
  final Future<ByteData> Function() _loadDemoBytes;

  AudioPlayerService? _audio;
  Wav? _baseWav;

  Future<void> init() async {
    await _engine.init();
    final repo = await _ref.read(presetRepositoryProvider.future);
    final gains = repo.loadGains();
    final name = repo.loadPresetName();
    final enabled = repo.loadEnabled();
    await _engine.setEnabled(enabled);
    state = state.copyWith(enabled: enabled);
    await _engine.setPreamp(repo.loadPreamp());
    state = state.copyWith(preampDb: repo.loadPreamp());
    if (gains != null && gains.length == state.bands.length) {
      await applyGains(gains, presetName: name ?? 'Custom', persist: false);
    }
    // Bind the audition player (overridden with a fake in tests).
    try {
      _audio = await _ref.read(audioPlayerServiceProvider.future);
    } catch (e) {
      debugPrint('[EqController] audio unavailable: $e');
    }
  }

  Future<void> setGain(int index, double gainDb) async {
    final clamped = gainDb.clamp(EqBand.minGainDb, EqBand.maxGainDb);
    final bands = List<EqBand>.of(state.bands);
    bands[index] = bands[index].copyWith(gainDb: clamped);
    state = state.copyWith(bands: bands, presetName: 'Custom');
    await _engine.setBandGain(index, clamped);
    await _persist();
    await _refreshAuditionSource();
  }

  Future<void> applyPreset(EqPreset preset) async {
    await applyGains(preset.gainsDb, presetName: preset.name);
  }

  Future<void> applyGains(List<double> gains,
      {required String presetName, bool persist = true}) async {
    final bands = [
      for (var i = 0; i < state.bands.length; i++)
        state.bands[i].copyWith(gainDb: gains[i].clamp(-12.0, 12.0)),
    ];
    state = state.copyWith(bands: bands, presetName: presetName);
    for (var i = 0; i < bands.length; i++) {
      await _engine.setBandGain(i, bands[i].gainDb);
    }
    if (persist) await _persist();
    await _refreshAuditionSource();
  }

  Future<void> reset() async {
    await applyGains(List.filled(state.bands.length, 0),
        presetName: 'Flat');
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _engine.setEnabled(value);
    await _persist();
    // The toggle is audible: bypass re-renders the untouched demo.
    await _refreshAuditionSource();
  }

  /// Play/pause the audition loop, preparing the rendered source first.
  /// After this returns, what you hear always matches the current state
  /// (gains + preamp + toggle).
  Future<void> toggleAudition() async {
    final audio = _audio;
    if (audio == null || audio.audioError != null) return;
    if (!audio.demoLoaded) {
      await _refreshAuditionSource(prepare: true);
      if (!audio.demoLoaded) return;
    }
    await audio.toggle();
  }

  Future<void> setPreamp(double preampDb) async {
    final clamped = preampDb.clamp(
      EqEngine.minPreampDb,
      EqEngine.maxPreampDb,
    );
    state = state.copyWith(preampDb: clamped);
    await _engine.setPreamp(clamped);
    await _persist();
    await _refreshAuditionSource();
  }

  /// Pick an APO `.txt` file and apply it. Returns the preset name, or null
  /// if the user cancelled. Throws [FormatException] on bad content —
  /// callers show it in a SnackBar.
  ///
  /// The APO preamp goes to the dedicated preamp (not smeared into bands).
  Future<String?> importFromFile() async {
    final apo = await _files.importApoPreset();
    if (apo == null) return null;
    await setPreamp(apo.preampDb);
    final freqs = state.bands.map((b) => b.frequencyHz).toList();
    await applyGains(
      apo.toGains(freqs, includePreamp: false),
      presetName: apo.name,
    );
    return apo.name;
  }

  /// Share current gains as an APO `.txt` file via the system share sheet.
  Future<void> exportToFile() => _files.exportPreset(
        name: state.presetName,
        bandFreqs: state.bands.map((b) => b.frequencyHz).toList(),
        gainsDb: state.gainsDb,
        preampDb: state.preampDb,
      );

  Future<void> _persist() async {
    final repo = await _ref.read(presetRepositoryProvider.future);
    await repo.saveGains(state.gainsDb);
    await repo.savePresetName(state.presetName);
    await repo.savePreamp(state.preampDb);
    await repo.saveEnabled(state.enabled);
  }

  /// Re-render the audition file from current state and hot-swap it under
  /// the player, preserving position and playing state.
  ///
  /// No-ops until the user first plays (nothing to refresh — pass
  /// [prepare] to force first preparation) and when the audio backend is
  /// broken. Failures are logged, never thrown — a render problem must not
  /// break slider movement.
  Future<void> _refreshAuditionSource({bool prepare = false}) async {
    final audio = _audio;
    if (audio == null || audio.audioError != null) return;
    if (!audio.demoLoaded && !prepare) return;
    try {
      _baseWav ??= Wav.read(_bytes(await _loadDemoBytes()));
      final rendered = renderAudition(
        base: _baseWav!,
        freqsHz: state.bands.map((b) => b.frequencyHz).toList(),
        gainsDb: state.gainsDb,
        preampDb: state.preampDb,
        enabled: state.enabled,
      );
      final dir = await _getTempDir();
      final file = File('${dir.path}/audition.wav');
      await file.writeAsBytes(rendered.write(), flush: true);
      final resume = audio.playing;
      Duration? position;
      try {
        position = await audio.position;
      } catch (_) {
        // Position is best-effort during source swaps.
      }
      await audio.setFile(file.path, initialPosition: position);
      if (resume) {
        try {
          await audio.play();
        } catch (_) {
          // Stay paused rather than crash the gesture.
        }
      }
      debugPrint(
        '[EqController] audition refreshed (enabled=${state.enabled})',
      );
    } catch (e) {
      debugPrint('[EqController] audition refresh failed: $e');
    }
  }

  static Uint8List _bytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
