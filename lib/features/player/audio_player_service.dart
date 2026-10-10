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

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<LoopMode> get loopStream => _player.loopModeStream;

  Future<void> setLoop(bool loop) =>
      _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);

  bool get playing => _player.playing;

  Future<Duration?> get position async {
    try {
      return _player.position;
    } catch (_) {
      return null;
    }
  }

  /// True once an audition source is loaded. False initially (source is
  /// prepared lazily on first play) and when the backend is missing — the
  /// UI then shows a notice instead of a dead play button.
  bool demoLoaded = false;

  /// Backend failure captured at init (e.g. no system libmpv on Linux).
  /// When set, auditioning is unavailable; everything else still works.
  String? audioError;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    debugPrint('[AudioPlayerService] session configured');
  }

  /// Load a rendered audition file. Sets [demoLoaded]. Restores [position]
  /// when hot-swapping the source under playing audio.
  Future<void> setFile(String path, {Duration? initialPosition}) async {
    await _player.setFilePath(path);
    demoLoaded = true;
    if (initialPosition != null) {
      try {
        await _player.seek(initialPosition);
      } catch (_) {
        // Seek is best-effort during source swaps.
      }
    }
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> toggle() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> toggleLoop() async {
    final mode = _player.loopMode;
    await setLoop(mode != LoopMode.one);
  }

  Future<void> dispose() => _player.dispose();
}

final audioPlayerServiceProvider = FutureProvider<AudioPlayerService>((
  ref,
) async {
  final service = AudioPlayerService();
  try {
    await service.init();
  } catch (e) {
    // No audio backend (e.g. headless CI, missing libmpv): record it and
    // let the UI degrade instead of crashing startup.
    service.audioError = e.toString();
    debugPrint('[AudioPlayerService] backend unavailable: $e');
  }
  ref.onDispose(service.dispose);
  return service;
});
