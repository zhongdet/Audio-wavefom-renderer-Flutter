import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../core/spectrum_painter.dart';
import '../models/visualizer_settings.dart';
import '../core/constants.dart';

class OffscreenRenderer {
  OffscreenRenderer({this.width = kExportWidth, this.height = kExportHeight});

  final int width;
  final int height;

  Future<Uint8List> renderFrame(
    Float64List heights,
    VisualizerSettings settings,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = settings.backgroundColor,
    );

    final size = Size(width.toDouble(), height.toDouble());
    SpectrumPainter.drawSpectrum(canvas, size, heights, settings);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    
    final pixels = byteData!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    
    return pixels;
  }
}
