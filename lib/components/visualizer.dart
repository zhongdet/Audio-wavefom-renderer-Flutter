import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../core/spectrum_painter.dart';
import '../models/visualizer_settings.dart';
import '../providers/providers.dart';

class SpectrumBarsPainter extends CustomPainter {
  final Float64List heights;
  final VisualizerSettings settings;

  SpectrumBarsPainter({required this.heights, required this.settings});

  @override
  void paint(Canvas canvas, Size size) {
    SpectrumPainter.drawSpectrum(canvas, size, heights, settings);
  }

  @override
  bool shouldRepaint(SpectrumBarsPainter oldDelegate) => true;
}

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
                builder: (context, _) => RepaintBoundary(
                  child: CustomPaint(
                    painter: SpectrumBarsPainter(
                      heights: preview.heights,
                      settings: settings,
                    ),
                  ),
                ),
              ),
            )
          : const Text('Upload an audio file to begin'),
    );
  }
}
