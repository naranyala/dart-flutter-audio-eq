import 'package:audio_eq/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EQ page renders bands and presets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AudioEqApp()));
    await tester.pumpAndSettle();

    expect(find.text('Audio EQ'), findsOneWidget);
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Bass Boost'), findsOneWidget);
  });
}
