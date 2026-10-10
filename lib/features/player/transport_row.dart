import 'package:flutter/material.dart';

/// Pure audition transport row: play/pause + track + session id.
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
    this.enabled = true,
    this.trackLabel = 'demo.wav — audition loop',
    this.position,
    this.duration,
    this.onSeek,
    this.looping = false,
    this.onToggleLoop,
  });

  final bool playing;
  final bool busy;
  final int? sessionId;
  final VoidCallback onToggle;

  /// False when no audio can play (missing backend): shows a notice
  /// instead of a dead play button.
  final bool enabled;

  final String trackLabel;
  final Duration? position;
  final Duration? duration;

  /// Null = seeking unavailable (no source yet): the row still renders a
  /// disabled slider so the layout doesn't jump when a source loads.
  final ValueChanged<Duration>? onSeek;
  final bool looping;
  final VoidCallback? onToggleLoop;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            'Demo audio unavailable (missing playback backend — see README)',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }
    final row = Row(
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
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: onToggle,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
        Expanded(
          child: Text(trackLabel, overflow: TextOverflow.ellipsis),
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
        if (onToggleLoop != null)
          IconButton(
            tooltip: looping ? 'Loop off' : 'Loop one',
            onPressed: onToggleLoop,
            icon: Icon(
              Icons.repeat_one,
              color: looping
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          )
        else
          const SizedBox(width: 4),
      ],
    );
    // The seek row always renders (disabled until a source loads) so
    // source swaps never shift the layout.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        SeekBar(
          position: position ?? Duration.zero,
          duration: duration ?? const Duration(seconds: 1),
          onSeek: duration == null ? null : onSeek,
        ),
      ],
    );
  }
}

/// Position slider with elapsed/total time. Pure widget, tested.
class SeekBar extends StatelessWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;

  /// Null disables the slider (no source loaded yet).
  final ValueChanged<Duration>? onSeek;

  static String fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds;
    final posMs = position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 1);
    return Row(
      children: [
        const SizedBox(width: 12),
        Text(fmt(position), style: Theme.of(context).textTheme.labelSmall),
        Expanded(
          child: Slider(
            min: 0,
            max: (maxMs > 0 ? maxMs : 1).toDouble(),
            value: posMs.toDouble(),
            onChanged: onSeek == null
                ? null
                : (v) => onSeek!(Duration(milliseconds: v.round())),
          ),
        ),
        Text(fmt(duration), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 12),
      ],
    );
  }
}
