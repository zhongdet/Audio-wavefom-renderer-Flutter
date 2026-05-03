import 'dart:typed_data';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:path_provider/path_provider.dart';

class HardwareExporter {
  String? _outputPath;

  Future<void> setup({
    required int width,
    required int height,
    required int fps,
  }) async {
    final dir = await getTemporaryDirectory();
    _outputPath =
        '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await FlutterQuickVideoEncoder.setup(
      width: width,
      height: height,
      fps: fps,
      videoBitrate: 2000000,
      profileLevel: ProfileLevel.any,
      audioBitrate: 0,
      audioChannels: 0,
      sampleRate: 0,
      filepath: _outputPath!,
    );
  }

  Future<void> appendVideoFrame(Uint8List rgbaPixels) async {
    await FlutterQuickVideoEncoder.appendVideoFrame(rgbaPixels);
  }

  Future<String> finish() async {
    await FlutterQuickVideoEncoder.finish();
    return _outputPath!;
  }
}
