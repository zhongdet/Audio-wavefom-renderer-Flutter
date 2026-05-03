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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth;
                  final canvasHeight = constraints.maxHeight;

                  // 计算缩放比例：使波形在预览区域中合适显示
                  // 基于导出分辨率和预览区域的比例来调整波形参数
                  final scale = canvasWidth / settings.resolution.width;

                  // 调整波形参数以适应预览画布
                  final adjustedSettings = settings.updateWith(
                    totalWidth: settings.totalWidth * scale,
                    barWidth: settings.barWidth * scale,
                    spacing: settings.spacing * scale,
                    cornerRadius: settings.cornerRadius * scale,
                  );

                  return SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
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
                  );
                },
              ),
            )
          : const Text('Upload an audio file to begin'),
    );
  }
}
