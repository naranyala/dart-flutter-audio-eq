import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/platform/platform_info.dart';
import '../../player/audio_player_service.dart';
import '../../player/transport_row.dart';
import '../domain/eq_engine.dart';
import 'eq_controller.dart';
import 'widgets/band_slider.dart';
import 'widgets/eq_curve.dart';

class EqPage extends ConsumerWidget {
  const EqPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(eqControllerProvider);
    final controller = ref.read(eqControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio EQ'),
        actions: [
          IconButton(
            tooltip: 'Import APO preset (.txt)',
            onPressed: () async {
              try {
                final name = await controller.importFromFile();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      name == null ? 'Import cancelled' : 'Imported "$name"',
                    ),
                  ),
                );
              } on FormatException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import failed: ${e.message}')),
                );
              }
            },
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Share preset as APO (.txt)',
            onPressed: () async {
              await controller.exportToFile();
            },
            icon: const Icon(Icons.share),
          ),
          Switch(
            value: eq.enabled,
            onChanged: controller.setEnabled,
          ),
          IconButton(
            tooltip: 'Reset to Flat',
            onPressed: controller.reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _PlatformBanner(),
          const _PlayerBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Preset: ${eq.presetName}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: eq.presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final preset = eq.presets[i];
                final selected = preset.name == eq.presetName;
                return ChoiceChip(
                  label: Text(preset.name),
                  selected: selected,
                  onSelected: (_) => controller.applyPreset(preset),
                );
              },
            ),
          ),
          _PreampRow(
            preampDb: eq.preampDb,
            onChanged: controller.setPreamp,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: EqCurveWidget(
              freqsHz: eq.bands.map((b) => b.frequencyHz).toList(),
              gainsDb: eq.gainsDb,
              preampDb: eq.preampDb,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Opacity(
              opacity: eq.enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !eq.enabled,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < eq.bands.length; i++)
                        Expanded(
                          child: BandSlider(
                            band: eq.bands[i],
                            onChanged: (v) => controller.setGain(i, v),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              PlatformInfo.hasNativeDsp
                  ? 'Native DSP active.'
                  : 'Preview mode: sliders persist locally. Play the demo loop '
                    'to audition, render to WAV for EQ\'d output. See README.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final label = PlatformInfo.label;
    final supported = PlatformInfo.isLinux || PlatformInfo.isAndroid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: supported
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Text(
        supported
            ? 'Running on $label — Tier 1 supported.'
            : 'Running on $label — Tier 2 (planned). UI preview only.',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// Audition transport: bundled demo loop + audio session id.
///
/// The session id is what the future Android native engine attaches its
/// `Equalizer` to — surfacing it here makes bug reports actionable.
void _noopToggle() {}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioPlayerServiceProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: service.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'Demo audio unavailable: $e',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        data: (s) {
          if (!s.demoLoaded) {
            return const TransportRow(
              playing: false,
              busy: false,
              sessionId: null,
              onToggle: _noopToggle,
              enabled: false,
            );
          }
          return StreamBuilder<PlayerState>(
            stream: s.playerStateStream,
            initialData: s.player.playerState,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              final processing =
                  snap.data?.processingState ?? ProcessingState.idle;
              return TransportRow(
                playing: playing,
                busy: processing == ProcessingState.loading ||
                    processing == ProcessingState.buffering,
                sessionId: s.androidAudioSessionId,
                onToggle: s.toggle,
              );
            },
          );
        },
      ),
    );
  }
}

/// Overall gain slider. Keeps boosted presets out of digital clipping —
/// AutoEQ corrections depend on negative preamp.
class _PreampRow extends StatelessWidget {
  const _PreampRow({required this.preampDb, required this.onChanged});

  final double preampDb;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('Pre', style: Theme.of(context).textTheme.labelMedium),
          Expanded(
            child: Slider(
              min: EqEngine.minPreampDb,
              max: EqEngine.maxPreampDb,
              divisions: 72,
              value: preampDb,
              label: '${preampDb.toStringAsFixed(1)} dB',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${preampDb.toStringAsFixed(1)} dB',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
