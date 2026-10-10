import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wav/wav.dart';

import 'package:audio_eq/features/dsp/audio_decode.dart';

Future<String> writeTemp(String name, {bool garbage = false}) async {
  final path = '${Directory.systemTemp.path}/$name';
  if (garbage) {
    await File(path).writeAsBytes([1, 2, 3, 4], flush: true);
  } else {
    final ch = Float64List(4410);
    for (var i = 0; i < ch.length; i++) {
      ch[i] = 0.3 * math.sin(2 * math.pi * 440 * i / 44100);
    }
    await File(path).writeAsBytes(Wav([ch], 44100).write(), flush: true);
  }
  return path;
}

void main() {
  test('WAV files parse directly without conversion', () async {
    final path = await writeTemp('decode-song.wav');
    final decoded = await decodeToWav(path, Directory.systemTemp);
    expect(decoded.formatLabel, 'WAV');
    expect(decoded.wasConverted, isFalse);
    expect(decoded.wav.samplesPerSecond, 44100);
    expect(decoded.wav.channels[0].length, 4410);
  });

  test('garbage WAV throws FormatException (direct-play fallback upstream)',
      () async {
    final path = await writeTemp('decode-garbage.wav', garbage: true);
    expect(
      decodeToWav(path, Directory.systemTemp),
      throwsA(isA<FormatException>()),
    );
  });

  test('formatOf + isWavPath helpers', () {
    expect(formatOf('song.MP3'), 'MP3');
    expect(formatOf('noext'), '?');
    expect(isWavPath('/a/b.WAV'), isTrue);
    expect(isWavPath('/a/b.flac'), isFalse);
  });
}
