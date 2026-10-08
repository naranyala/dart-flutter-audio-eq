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
}

void _noop() {}
