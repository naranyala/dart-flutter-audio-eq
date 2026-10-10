import 'package:audio_eq/app.dart';
import 'package:audio_eq/features/eq/presentation/widgets/eq_curve.dart';
import 'package:audio_eq/features/player/audio_player_service.dart';
import 'package:audio_eq/features/player/transport_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audio plugins don't exist in widget tests, so the player provider is
/// overridden: error state (graceful degradation) or a real-but-uninit
/// service (data branch with idle local player state).
Override failingAudio() => audioPlayerServiceProvider.overrideWith(
      (_) => throw Exception('no audio in tests'),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('EQ page renders bands, presets, preamp, and curve', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [failingAudio()],
        child: const AudioEqApp(),
      ),
    );
    await settle(tester);

    expect(find.text('Audio EQ'), findsOneWidget);
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Bass Boost'), findsOneWidget);
    expect(find.byType(EqCurveWidget), findsOneWidget);
    expect(find.text('Pre'), findsOneWidget);
    // Graceful degradation notice, EQ still usable.
    expect(find.textContaining('Demo audio unavailable'), findsOneWidget);
  });

  testWidgets('TransportRow shows transport + session id', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: false,
            busy: false,
            sessionId: 42,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.textContaining('session 42'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(toggled, isTrue);
  });

  testWidgets('TransportRow reflects playing + busy states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: true,
            busy: true,
            sessionId: null,
            onToggle: _noop,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.pause), findsNothing); // busy spinner wins
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('session'), findsOneWidget);
  });

  testWidgets('TransportRow shows notice when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: false,
            busy: false,
            sessionId: null,
            onToggle: _noop,
            enabled: false,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.textContaining('Demo audio unavailable'), findsOneWidget);
  });

  testWidgets('TransportRow seek bar seeks and shows times', (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: true,
            busy: false,
            sessionId: null,
            onToggle: _noop,
            trackLabel: 'song.mp3 · MP3 · EQ',
            position: const Duration(seconds: 65),
            duration: const Duration(seconds: 125),
            onSeek: (d) => sought = d,
          ),
        ),
      ),
    );

    expect(find.text('song.mp3 · MP3 · EQ'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(
      find.byType(Slider),
      const Offset(40, 0),
    );
    await tester.pump();
    expect(sought, isNotNull);
  });

  testWidgets('TransportRow loop toggle reflects state', (tester) async {    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: false,
            busy: false,
            sessionId: null,
            onToggle: _noop,
            looping: true,
            onToggleLoop: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.repeat_one), findsOneWidget);
    await tester.tap(find.byIcon(Icons.repeat_one));
    expect(toggled, isTrue);
  });

  testWidgets('SeekBar renders disabled without a source (no layout jump)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransportRow(
            playing: false,
            busy: false,
            sessionId: null,
            onToggle: _noop,
          ),
        ),
      ),
    );

    // Seek row always present; slider disabled until duration arrives.
    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
    expect(find.text('0:00'), findsOneWidget); // position
    expect(find.text('0:01'), findsOneWidget); // placeholder duration
  });
}

void _noop() {}
