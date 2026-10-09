import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Bundled audition sample (generated, see `tool/make_demo_wav.py`).
const demoAsset = 'assets/samples/demo.wav';

/// Thin wrapper around just_audio for auditioning EQ changes.
///
/// Playback itself is NOT equalized yet (MockEqEngine) — this gives
/// transport + session setup so native engines can attach later.
/// Linux playback works via `just_audio_media_kit` + `media_kit_libs_linux`.
///
/// Android next step: pass [androidAudioSessionId] into
/// android.media.audiofx.Equalizer via MethodChannel.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  AudioPlayer get player => _player;

  int? get androidAudioSessionId => _player.androidAudioSessionId;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// True once the bundled demo asset loaded. False when the playback
  /// backend is missing (e.g. no system libmpv on Linux) — the UI then
  /// shows a notice instead of a dead play button.
  bool demoLoaded = false;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    debugPrint('[AudioPlayerService] session configured');
  }

  /// Load the bundled demo loop (idempotent). Sets [demoLoaded].
  Future<void> loadDemo() async {
    await _player.setAsset(demoAsset, preload: true);
    demoLoaded = true;
  }

  Future<void> toggle() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> dispose() => _player.dispose();
}

final audioPlayerServiceProvider = FutureProvider<AudioPlayerService>((
  ref,
) async {
  final service = AudioPlayerService();
  await service.init();
  try {
    await service.loadDemo();
  } catch (e) {
    // Asset/decoder missing (e.g. headless CI): transport shows an error
    // state instead of crashing startup.
    debugPrint('[AudioPlayerService] demo load failed: $e');
  }
  ref.onDispose(service.dispose);
  return service;
});
