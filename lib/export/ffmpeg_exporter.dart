import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';

class FFmpegExportException implements Exception {
  FFmpegExportException(this.message);
  final String message;
}

class FFmpegExporter {
  String? _pipePath;
  String? _outputPath;

  Future<String> setupPipe() async {
    final dir = await getTemporaryDirectory();
    final pipesDir = Directory('${dir.path}/pipes');
    if (!await pipesDir.exists()) {
      await pipesDir.create(recursive: true);
    }

    _pipePath = await FFmpegKitConfig.registerNewFFmpegPipe();
    _outputPath =
        '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return _pipePath!;
  }

  Future<String> executeCommand() async {
    assert(_pipePath != null && _outputPath != null);
    final cmd =
        '-f rawvideo '
        '-pixel_format rgba '
        '-video_size ${kExportWidth}x$kExportHeight '
        '-framerate $kExportFps '
        '-i $_pipePath '
        '-c:v libx264 '
        '-pix_fmt yuv420p '
        '-preset ultrafast '
        '-crf 23 '
        '$_outputPath';

    final completer = Completer<String>();
    await FFmpegKit.executeAsync(cmd, (session) async {
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        completer.complete(_outputPath!);
      } else {
        final log = await session.getOutput();
        completer.completeError(FFmpegExportException(log ?? 'FFmpeg failed'));
      }
    });
    return completer.future;
  }

  Future<void> closePipe() async {
    if (_pipePath != null) {
      await FFmpegKitConfig.closeFFmpegPipe(_pipePath!);
    }
  }
}
