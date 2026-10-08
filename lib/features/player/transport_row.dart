import 'package:flutter/material.dart';

/// Pure audition transport row: play/pause + session id.
///
/// Split from the provider/stream plumbing so it is unit-testable without
/// audio plugins. See `_PlayerBar` in `eq_page.dart` for the wiring.
class TransportRow extends StatelessWidget {
  const TransportRow({
    super.key,
    required this.playing,
    required this.busy,
    required this.sessionId,
    required this.onToggle,
  });

  final bool playing;
  final bool busy;
  final int? sessionId;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (busy)
          const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          IconButton(
            tooltip: playing ? 'Pause demo' : 'Play demo loop',
            onPressed: onToggle,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
        const Expanded(
          child: Text(
            'demo.wav — audition loop',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Tooltip(
          message: 'Audio session id for the native engine (Android)',
          child: Text(
            'session ${sessionId ?? '—'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
