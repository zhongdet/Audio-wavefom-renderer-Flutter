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

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: preview != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  // 计算16:9尺寸，尽可能填满可用空间
                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;

                  double width, height;
                  if (maxWidth / maxHeight > 16 / 9) {
                    // 以高度为基准
                    height = maxHeight;
                    width = height * 16 / 9;
                  } else {
                    // 以宽度为基准
                    width = maxWidth;
                    height = width * 9 / 16;
                  }

                  final scale = width / settings.resolution.width;

                  final adjustedSettings = settings.updateWith(
                    totalWidth: settings.totalWidth * scale,
                    barWidth: settings.barWidth * scale,
                    spacing: settings.spacing * scale,
                    cornerRadius: settings.cornerRadius * scale,
                  );

                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: ListenableBuilder(
                        listenable: preview,
                        builder: (context, _) => RepaintBoundary(
                          child: CustomPaint(
                            painter: SpectrumBarsPainter(
                              heights: preview.heights,
                              settings: adjustedSettings,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            : const Center(child: Text('Upload an audio file to begin')),
      ),
    );
  }
}
