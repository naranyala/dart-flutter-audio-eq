import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wav/wav.dart';

import 'package:audio_eq/features/dsp/audio_decode.dart';
import 'package:audio_eq/features/eq/data/apo_preset.dart';
import 'package:audio_eq/features/eq/domain/eq_preset.dart';
import 'package:audio_eq/features/eq/data/preset_file_service.dart';
import 'package:audio_eq/features/eq/data/preset_repository.dart';
import 'package:audio_eq/features/eq/domain/eq_engine.dart';
import 'package:audio_eq/features/eq/presentation/eq_controller.dart';
import 'package:audio_eq/features/player/audio_player_service.dart';
import 'package:audio_eq/main.dart';

class FakeEngine implements EqEngine {
  @override
  List<double> frequenciesHz = const [60, 230, 910, 3600, 14000];

  final bandCalls = <int, double>{};
  double lastPreamp = 0;
  var enabled = true;

  @override
  Future<void> init() async {}

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    bandCalls[bandIndex] = gainDb;
  }

  @override
  Future<void> setPreamp(double preampDb) async {
    lastPreamp = preampDb;
  }

  @override
  Future<void> dispose() async {}
}

class FakeFiles extends PresetFileService {
  ApoPreset? toImport;
  Map<String, Object?>? exported;

  @override
  Future<ApoPreset?> importApoPreset() async => toImport;

  @override
  Future<void> exportPreset({
    required String name,
    required List<double> bandFreqs,
    required List<double> gainsDb,
    double preampDb = 0,
  }) async {
    exported = {
      'name': name,
      'bandFreqs': bandFreqs,
      'gainsDb': gainsDb,
      'preampDb': preampDb,
    };
  }
}

class FakeAudio extends AudioPlayerService {
  final setFiles = <String>[];
  var isPlaying = false;
  var playCalls = 0;

  /// Artificial latency to force overlapping refreshes in race tests.
  Duration setFileDelay = Duration.zero;

  @override
  bool get playing => isPlaying;

  @override
  Future<Duration?> get position async => Duration.zero;

  @override
  Future<void> setFile(String path, {Duration? initialPosition}) async {
    if (setFileDelay > Duration.zero) {
      await Future<void>.delayed(setFileDelay);
    }
    setFiles.add(path);
    demoLoaded = true;
  }

  @override
  Future<void> toggle() async {
    isPlaying = !isPlaying;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playCalls++;
  }

  @override
  Future<void> dispose() async {}
}

Future<ProviderContainer> makeContainer({
  Map<String, Object>? prefs,
  required FakeEngine engine,
  required FakeFiles files,
  FakeAudio? audio,
  Future<Directory> Function()? tempDir,
  Future<ByteData> Function()? demoBytes,
  Future<({String name, String path})?> Function()? pickAudio,
  Future<DecodedAudio> Function(String, Directory)? decodeFile,
  Duration? debounce,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  final repo = PresetRepository(await SharedPreferences.getInstance());
  late EqController controller;
  final container = ProviderContainer(
    overrides: [
      eqEngineProvider.overrideWithValue(engine),
      presetRepositoryProvider.overrideWith((_) => repo),
      if (audio != null) audioPlayerServiceProvider.overrideWith((_) => audio),
      eqControllerProvider.overrideWith((ref) {
        controller = EqController(
          engine,
          ref,
          files,
          tempDir,
          demoBytes,
          pickAudio,
          decodeFile,
          debounce,
        );
        return controller;
      }),
    ],
  );
  addTearDown(container.dispose);
  // First read triggers creation; the override skips the default unawaited
  // init, so await it explicitly.
  container.read(eqControllerProvider);
  await controller.init();
  return container;
}

/// 0.1 s 440 Hz tone as the fake demo asset.
Future<ByteData> testDemoBytes() async {
  const rate = 44100;
  final ch = Float64List(4410);
  for (var i = 0; i < ch.length; i++) {
    ch[i] = 0.3 * math.sin(2 * math.pi * 440 * i / rate);
  }
  return ByteData.sublistView(Wav([ch], rate).write());
}

void main() {
  // Plugin constructors (just_audio, audio_session, shared_preferences
  // channels) need a binding even in non-widget tests. Channel *calls*
  // still throw MissingPluginException, which the app code catches.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setGain clamps to ±12 dB and marks preset Custom', () async {
    final engine = FakeEngine();
    final container = await makeContainer(
      engine: engine,
      files: FakeFiles(),
    );
    final controller = container.read(eqControllerProvider.notifier);

    await controller.setGain(0, 99);
    expect(container.read(eqControllerProvider).bands[0].gainDb, 12);
    expect(engine.bandCalls[0], 12);
    expect(container.read(eqControllerProvider).presetName, 'Custom');

    await controller.setGain(1, -99);
    expect(container.read(eqControllerProvider).bands[1].gainDb, -12);
    expect(engine.bandCalls[1], -12);
  });

  test('setPreamp clamps, forwards to engine, and persists', () async {
    final engine = FakeEngine();
    final container = await makeContainer(
      engine: engine,
      files: FakeFiles(),
    );
    final controller = container.read(eqControllerProvider.notifier);

    await controller.setPreamp(-99);
    expect(container.read(eqControllerProvider).preampDb, -24);
    expect(engine.lastPreamp, -24);

    await controller.setPreamp(3.5);
    expect(container.read(eqControllerProvider).preampDb, 3.5);

    final repo = await container.read(presetRepositoryProvider.future);
    expect(repo.loadPreamp(), 3.5);
  });

  test('init restores gains + preamp from persistence', () async {
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      prefs: {
        'eq_gains_db': jsonEncode([1.0, 2.0, 3.0, 4.0, 5.0]),
        'eq_preset_name': 'Restored',
        'eq_preamp_db': -6.0,
      },
    );
    final state = container.read(eqControllerProvider);
    expect(state.gainsDb, [1.0, 2.0, 3.0, 4.0, 5.0]);
    expect(state.preampDb, -6.0);
    expect(state.presetName, 'Restored');
  });

  test('import routes preamp to preamp, not into bands', () async {
    final files = FakeFiles()
      ..toImport = const ApoPreset(
        name: 'HP',
        preampDb: -6,
        filters: [
          ApoFilter(type: ApoFilterType.peak, frequencyHz: 910, gainDb: 4),
        ],
      );
    final container = await makeContainer(
      engine: FakeEngine(),
      files: files,
    );
    final controller = container.read(eqControllerProvider.notifier);

    final name = await controller.importFromFile();
    expect(name, 'HP');
    final state = container.read(eqControllerProvider);
    expect(state.preampDb, -6);
    // 910 Hz is band 2; no -6 smear anywhere.
    expect(state.gainsDb, [0, 0, 4, 0, 0]);
    expect(state.presetName, 'HP');
  });

  test('export carries the real preamp', () async {
    final files = FakeFiles();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: files,
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.setPreamp(-4.5);
    await controller.setGain(2, 3);

    await controller.exportToFile();
    expect(files.exported!['preampDb'], -4.5);
    expect((files.exported!['gainsDb'] as List)[2], 3);
  });

  test('setEnabled persists across restarts', () async {
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.setEnabled(false);

    final repo = await container.read(presetRepositoryProvider.future);
    expect(repo.loadEnabled(), isFalse);

    // Fresh controller over the same prefs restores the toggle.
    final container2 = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      prefs: {
        'eq_enabled': false,
        'eq_gains_db': jsonEncode([0.0, 0.0, 0.0, 0.0, 0.0]),
      },
    );
    expect(container2.read(eqControllerProvider).enabled, isFalse);
  });

  test('first toggle prepares a rendered source; toggle bypasses it', () async {
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
    );
    final controller = container.read(eqControllerProvider.notifier);
    // applyPreset refreshes immediately (no debounce timer involved).
    await controller.applyPreset(
      const EqPreset(name: 'B', gainsDb: [0, 0, 6, 0, 0]),
    );

    // Nothing rendered before first play.
    expect(audio.setFiles, isEmpty);

    await controller.toggleAudition();
    expect(audio.setFiles.length, 1);
    expect(audio.isPlaying, isTrue);
    final boosted = await File(audio.setFiles.single).readAsBytes();

    await controller.setEnabled(false);
    expect(audio.setFiles.length, 2);
    final bypass = await File(audio.setFiles.last).readAsBytes();

    // Bypass file is the untouched demo; boosted render differs.
    final base = Wav.read((await testDemoBytes()).buffer.asUint8List());
    expect(bypass, base.write());
    expect(boosted, isNot(equals(bypass)));
  });

  test('preset changes while playing hot-swap the source and resume', () async {
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.toggleAudition();
    expect(audio.isPlaying, isTrue);

    await controller.applyPreset(
      const EqPreset(name: 'B', gainsDb: [6, 0, 0, 0, 0]),
    );
    expect(audio.setFiles.length, 2);
    expect(audio.isPlaying, isTrue);
    expect(audio.playCalls, 1); // resumed after the swap
  });

  test('slider drags coalesce into one render (debounce)', () async {
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.toggleAudition();
    expect(audio.setFiles.length, 1);

    // Rapid drag: only the last state renders once.
    await controller.setGain(0, 1);
    await controller.setGain(0, 2);
    await controller.setGain(0, 3);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(audio.setFiles.length, 2);
    expect(container.read(eqControllerProvider).bands[0].gainDb, 3);
  });

  test('openUserFile auditions a picked WAV through the EQ', () async {
    final wavPath = await _writeTempWav('user-song.wav');
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
      pickAudio: () async => (name: 'user-song.wav', path: wavPath),
    );
    final controller = container.read(eqControllerProvider.notifier);

    final name = await controller.openUserFile();
    expect(name, 'user-song.wav');
    expect(container.read(eqControllerProvider).auditionLabel,
        'user-song.wav · WAV · EQ');
    expect(controller.auditionEqCapable, isTrue);
    expect(audio.setFiles.length, 1);
  });

  test('undecodable file plays direct with a notice', () async {
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
      pickAudio: () async => (name: 'weird.xyz', path: '/tmp/weird.xyz'),
      decodeFile: (p, d) async => throw const FormatException('nope'),
    );
    final controller = container.read(eqControllerProvider.notifier);

    final name = await controller.openUserFile();
    expect(name, 'weird.xyz');
    expect(controller.auditionEqCapable, isFalse);
    expect(container.read(eqControllerProvider).auditionLabel,
        contains('no EQ'));
    // Direct path handed to the player untouched.
    expect(audio.setFiles.single, '/tmp/weird.xyz');
  });

  test('cancelled file pick is a no-op', () async {    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
      pickAudio: () async => null,
    );
    final controller = container.read(eqControllerProvider.notifier);

    expect(await controller.openUserFile(), isNull);
    expect(audio.setFiles, isEmpty);
    expect(container.read(eqControllerProvider).trackName, 'demo.wav');
  });

  test('overlapping refreshes serialize: 3 concurrent toggles, 2 loads',
      () async {
    final audio = FakeAudio()
      ..setFileDelay = const Duration(milliseconds: 50);
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
    );
    final controller = container.read(eqControllerProvider.notifier);

    // Three overlapping prepares: first runs, other two coalesce into one
    // trailing run instead of interleaving three render→write→load cycles.
    final results = await Future.wait([
      controller.toggleAudition(),
      controller.toggleAudition(),
      controller.toggleAudition(),
    ]);
    expect(results, [isNull, isNull, isNull]);
    expect(audio.setFiles.length, 2);
  });

  test('direct-mode toggle skips the pointless reload', () async {
    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
      pickAudio: () async => (name: 'weird.xyz', path: '/tmp/weird.xyz'),
      decodeFile: (p, d) async => throw const FormatException('nope'),
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.openUserFile();
    expect(audio.setFiles.length, 1);

    // Same file, same bytes: reloading would only cause a dropout.
    await controller.setEnabled(false);
    expect(audio.setFiles.length, 1);
  });

  test('previous converted file is deleted on next open', () async {
    final first = await _writeTempWav('conv-one.wav');
    final second = await _writeTempWav('conv-two.wav');
    var pickPath = first;
    Future<DecodedAudio> fakeDecode(String path, Directory dir) async {
      const rate = 44100;
      final ch = Float64List(100);
      return DecodedAudio(
        wav: Wav([ch], rate),
        formatLabel: 'MP3',
        wasConverted: true,
        decodedPath: path,
      );
    }

    final audio = FakeAudio();
    final container = await makeContainer(
      engine: FakeEngine(),
      files: FakeFiles(),
      audio: audio,
      tempDir: () async => Directory.systemTemp,
      demoBytes: testDemoBytes,
      debounce: Duration.zero,
      pickAudio: () async =>
          (name: pickPath.split('/').last, path: pickPath),
      decodeFile: fakeDecode,
    );
    final controller = container.read(eqControllerProvider.notifier);
    await controller.openUserFile();
    expect(File(first).existsSync(), isTrue);
    expect(controller.auditionEqCapable, isTrue);

    // Swap happens before deletion, so the player never loses its file.
    pickPath = second;
    await controller.openUserFile();
    expect(File(first).existsSync(), isFalse);
    expect(File(second).existsSync(), isTrue);
    expect(audio.setFiles.length, 2);
  });
}

/// Write the fake demo bytes to a real temp `.wav` file for picker tests.
Future<String> _writeTempWav(String name) async {
  final bytes = (await testDemoBytes()).buffer.asUint8List();
  final path = '${Directory.systemTemp.path}/$name';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
