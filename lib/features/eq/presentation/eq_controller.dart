import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';

import '../../../main.dart';
import '../../dsp/audio_decode.dart';
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
    this.trackName = 'demo.wav',
    this.trackNote = '',
  });

  final List<EqBand> bands;
  final bool enabled;
  final String presetName;
  final List<EqPreset> presets;

  /// Overall gain in dB, range [EqEngine.minPreampDb, EqEngine.maxPreampDb].
  final double preampDb;

  /// Currently loaded audition track (bundled demo by default).
  final String trackName;

  /// Extra track info, e.g. `MP3 · EQ` or `XYZ · original (no EQ)`.
  final String trackNote;

  List<double> get gainsDb => bands.map((b) => b.gainDb).toList();

  /// One-line player label, e.g. `song.mp3 · MP3 · EQ`.
  String get auditionLabel =>
      trackNote.isEmpty ? trackName : '$trackName · $trackNote';

  EqState copyWith({
    List<EqBand>? bands,
    bool? enabled,
    String? presetName,
    List<EqPreset>? presets,
    double? preampDb,
    String? trackName,
    String? trackNote,
  }) =>
      EqState(
        bands: bands ?? this.bands,
        enabled: enabled ?? this.enabled,
        presetName: presetName ?? this.presetName,
        presets: presets ?? this.presets,
        preampDb: preampDb ?? this.preampDb,
        trackName: trackName ?? this.trackName,
        trackNote: trackNote ?? this.trackNote,
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
    Future<({String name, String path})?> Function()? pickAudio,
    Future<DecodedAudio> Function(String, Directory)? decodeFile,
    Duration? auditionDebounce,
  ])  : _files = files ?? PresetFileService(),
        _getTempDir = getTempDir ?? getTemporaryDirectory,
        _loadDemoBytes = loadDemoBytes ?? (() => rootBundle.load(demoAsset)),
        _pickAudio = pickAudio ?? _defaultPickAudio,
        _decodeFile = decodeFile ?? decodeToWav,
        _debounce = auditionDebounce ?? const Duration(milliseconds: 250),
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
  final Future<({String name, String path})?> Function() _pickAudio;
  final Future<DecodedAudio> Function(String, Directory) _decodeFile;
  final Duration _debounce;

  AudioPlayerService? _audio;
  Wav? _baseWav;

  /// User-loaded track (null = bundled demo). Rendered through EQ when set.
  Wav? _userWav;

  /// Non-null when the current track plays unprocessed because the platform
  /// could not decode it (direct file path, EQ unavailable).
  String? _directPath;

  Timer? _auditionTimer;

  /// Serializes refreshes: rapid preset hops / slider+preset interleaves
  /// used to run concurrent render→write→load cycles, letting a stale
  /// render win. Overlap now coalesces into a single trailing run.
  bool _refreshActive = false;
  bool _refreshQueued = false;

  /// Path currently loaded in the player (to skip identical reloads).
  String? _loadedPath;

  /// Converted temp file from the last user-file open (deleted on next
  /// open — decode outputs accumulate otherwise).
  String? _lastDecodedPath;

  /// True when the current track runs through the EQ (false = direct play).
  bool get auditionEqCapable => _directPath == null;

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
    _scheduleAuditionRefresh();
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

  /// Seek the audition track (transport completeness, no DSP involved).
  Future<void> seekTo(Duration position) async {
    try {
      await _audio?.seek(position);
    } catch (_) {
      // Best-effort transport control.
    }
  }

  /// Toggle single-track loop.
  Future<void> toggleLoop() async {
    try {
      await _audio?.toggleLoop();
    } catch (_) {
      // Best-effort transport control.
    }
  }

  /// Open a user audio file for audition. WAV (or platform-decodable
  /// MP3/FLAC/OGG/…) runs through the EQ; undecodable files play direct
  /// with a notice. Returns the track name, or null on cancel.
  Future<String?> openUserFile() async {
    final picked = await _pickAudio();
    if (picked == null) return null;
    _directPath = null;
    _userWav = null;
    String? newDecodedPath;
    try {
      final dir = await _getTempDir();
      final decoded = await _decodeFile(picked.path, dir);
      _userWav = decoded.wav;
      newDecodedPath = decoded.decodedPath;
      state = state.copyWith(
        trackName: picked.name,
        trackNote: '${decoded.formatLabel} · EQ',
      );
    } catch (e) {
      debugPrint('[EqController] decode failed, direct play: $e');
      _directPath = picked.path;
      state = state.copyWith(
        trackName: picked.name,
        trackNote: '${formatOf(picked.name)} · original (no EQ)',
      );
    }
    await _refreshAuditionSource(prepare: true);
    // Swap first, delete after: the player may still hold the old file.
    await _deleteQuietly(_lastDecodedPath);
    _lastDecodedPath = newDecodedPath;
    return state.trackName;
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {
      // Best-effort temp hygiene.
    }
  }

  /// Debounced refresh for continuous gestures (slider drags): coalesces
  /// rapid mutations into one render + disk write. Discrete gestures
  /// (toggle, preset, import, file open) refresh immediately.
  void _scheduleAuditionRefresh() {
    _auditionTimer?.cancel();
    _auditionTimer = Timer(_debounce, () {
      unawaited(_refreshAuditionSource());
    });
  }

  @override
  void dispose() {
    _auditionTimer?.cancel();
    super.dispose();
  }

  Future<void> setPreamp(double preampDb) async {
    final clamped = preampDb.clamp(
      EqEngine.minPreampDb,
      EqEngine.maxPreampDb,
    );
    state = state.copyWith(preampDb: clamped);
    await _engine.setPreamp(clamped);
    await _persist();
    _scheduleAuditionRefresh();
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
    if (_refreshActive) {
      _refreshQueued = true;
      return;
    }
    _refreshActive = true;
    try {
      do {
        _refreshQueued = false;
        // A trailing debounced render from earlier drags must not reload
        // right after this immediate one (double dropout).
        _auditionTimer?.cancel();
        await _doRefresh(audio);
      } while (_refreshQueued);
    } finally {
      _refreshActive = false;
    }
  }

  Future<void> _doRefresh(AudioPlayerService audio) async {
    try {
      Duration? position;
      if (audio.demoLoaded) {
        position = await audio.position;
      }
      final resume = audio.playing;
      final path = await _resolveAuditionFile();
      if (path == _loadedPath && _directPath != null) {
        // Direct-play file, identical bytes: reloading only causes a
        // dropout with zero audible change (e.g. toggling EQ on an
        // undecodable track).
        return;
      }
      await audio.setFile(path, initialPosition: position);
      _loadedPath = path;
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

  /// Resolve what the player should load: the direct file when the track
  /// is undecodable, otherwise a freshly rendered temp WAV.
  Future<String> _resolveAuditionFile() async {
    final direct = _directPath;
    if (direct != null) return direct;
    _baseWav ??= Wav.read(_bytes(await _loadDemoBytes()));
    final base = _userWav ?? _baseWav!;
    final rendered = renderAudition(
      base: base,
      freqsHz: state.bands.map((b) => b.frequencyHz).toList(),
      gainsDb: state.gainsDb,
      preampDb: state.preampDb,
      enabled: state.enabled,
    );
    final dir = await _getTempDir();
    final file = File('${dir.path}/audition.wav');
    await file.writeAsBytes(rendered.write(), flush: true);
    return file.path;
  }

  static Uint8List _bytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  static Future<({String name, String path})?> _defaultPickAudio() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return null;
    final file = files.first;
    final path = file.path;
    if (path == null) return null;
    return (name: file.name, path: path);
  }
}
