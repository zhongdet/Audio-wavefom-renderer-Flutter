import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../core/spectrum_painter.dart';
import '../core/visualizer_settings.dart';
import '../core/constants.dart';

class OffscreenRenderer {
  OffscreenRenderer({this.width = kExportWidth, this.height = kExportHeight});

  final int width;
  final int height;

  Future<Uint8List> renderFrame(
    Float64List heights,
    Float32List waveformSamples,
    VisualizerSettings settings,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    final size = Size(width.toDouble(), height.toDouble());
    SpectrumPainter.drawSpectrum(canvas, size, heights, settings);
    SpectrumPainter.drawWave(canvas, size, waveformSamples);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();

    return byteData!.buffer.asUint8List();
  }
}
