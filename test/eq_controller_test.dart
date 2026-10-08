import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audio_eq/features/eq/data/apo_preset.dart';
import 'package:audio_eq/features/eq/data/preset_file_service.dart';
import 'package:audio_eq/features/eq/data/preset_repository.dart';
import 'package:audio_eq/features/eq/domain/eq_engine.dart';
import 'package:audio_eq/features/eq/presentation/eq_controller.dart';
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

Future<ProviderContainer> makeContainer({
  Map<String, Object>? prefs,
  required FakeEngine engine,
  required FakeFiles files,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  final repo = PresetRepository(await SharedPreferences.getInstance());
  late EqController controller;
  final container = ProviderContainer(
    overrides: [
      eqEngineProvider.overrideWithValue(engine),
      presetRepositoryProvider.overrideWith((_) => repo),
      eqControllerProvider.overrideWith((ref) {
        controller = EqController(engine, ref, files);
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

void main() {
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
}
