import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';

class FFmpegExportException implements Exception {
  FFmpegExportException(this.message);
  final String message;
}

class FFmpegExporter {
  String? _rawFilePath;
  String? _outputPath;
  IOSink? _rawFileSink;

  Future<String> setupRawFile() async {
    final dir = await getTemporaryDirectory();
    _rawFilePath =
        '${dir.path}/raw_frames_${DateTime.now().millisecondsSinceEpoch}.rgba';
    _outputPath =
        '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final rawFile = File(_rawFilePath!);
    _rawFileSink = rawFile.openWrite(mode: FileMode.write);
    return _rawFilePath!;
  }

  void writeFrame(Uint8List pixels) {
    _rawFileSink?.add(pixels);
  }

  Future<String> executeCommand() async {
    assert(_rawFilePath != null && _outputPath != null);
    await _rawFileSink?.flush();
    await _rawFileSink?.close();

    final cmd =
        '-f rawvideo '
        '-pixel_format rgba '
        '-video_size ${kExportWidth}x$kExportHeight '
        '-framerate $kExportFps '
        '-i $_rawFilePath '
        '-c:v libx264 '
        '-pix_fmt yuv420p '
        '-preset ultrafast '
        '-crf 23 '
        '$_outputPath';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return _outputPath!;
    } else {
      final log = await session.getOutput();
      throw FFmpegExportException(log ?? 'FFmpeg failed');
    }
  }

  Future<void> cleanup() async {
    if (_rawFilePath != null) {
      final rawFile = File(_rawFilePath!);
      if (await rawFile.exists()) {
        await rawFile.delete();
      }
    }
  }
}
