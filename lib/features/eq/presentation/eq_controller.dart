import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
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
  EqController(this._engine, this._ref, [PresetFileService? files])
      : _files = files ?? PresetFileService(),
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

  Future<void> init() async {
    await _engine.init();
    final repo = await _ref.read(presetRepositoryProvider.future);
    final gains = repo.loadGains();
    final name = repo.loadPresetName();
    await _engine.setPreamp(repo.loadPreamp());
    state = state.copyWith(preampDb: repo.loadPreamp());
    if (gains != null && gains.length == state.bands.length) {
      await applyGains(gains, presetName: name ?? 'Custom', persist: false);
    }
  }

  Future<void> setGain(int index, double gainDb) async {
    final clamped = gainDb.clamp(EqBand.minGainDb, EqBand.maxGainDb);
    final bands = List<EqBand>.of(state.bands);
    bands[index] = bands[index].copyWith(gainDb: clamped);
    state = state.copyWith(bands: bands, presetName: 'Custom');
    await _engine.setBandGain(index, clamped);
    await _persist();
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
  }

  Future<void> reset() async {
    await applyGains(List.filled(state.bands.length, 0),
        presetName: 'Flat');
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _engine.setEnabled(value);
  }

  Future<void> setPreamp(double preampDb) async {
    final clamped = preampDb.clamp(
      EqEngine.minPreampDb,
      EqEngine.maxPreampDb,
    );
    state = state.copyWith(preampDb: clamped);
    await _engine.setPreamp(clamped);
    await _persist();
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
  }
}
