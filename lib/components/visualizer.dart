import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../preview/waveform_painter.dart';
import '../providers/providers.dart';

class MainVisualizer extends ConsumerWidget {
  const MainVisualizer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visState = ref.watch(visualizerProvider);
    final preview = visState.previewController;
    final settings = ref.watch(visualizerSettingsProvider);

    return Center(
      child: preview != null
          ? AspectRatio(
              aspectRatio: 16 / 9,
              child: ListenableBuilder(
                listenable: preview,
                builder: (context, _) => CustomPaint(
                  painter: WaveformPainter(
                    heights: preview.heights,
                    waveformSamples: preview.waveformSamples,
                    settings: settings.toCoreSettings(),
                  ),
                ),
              ),
            )
          : const Text('Upload an audio file to begin'),
    );
  }
}
