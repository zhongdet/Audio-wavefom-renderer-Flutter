import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

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

  Future<String> executeCommand({
    required int width,
    required int height,
    required int fps,
    required String preset,
    required int crf,
  }) async {
    assert(_rawFilePath != null && _outputPath != null);
    await _rawFileSink?.flush();
    await _rawFileSink?.close();

    String quote(String path) => "'${path.replaceAll("'", "'\\''")}'";

    final cmd =
        '-f rawvideo '
        '-pixel_format rgba '
        '-video_size ${width}x$height '
        '-framerate $fps '
        '-i ${quote(_rawFilePath!)} '
        '-c:v libx264 '
        '-pix_fmt yuv420p '
        '-preset $preset '
        '-crf $crf '
        '${quote(_outputPath!)}';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return _outputPath!;
    } else {
      final log = await session.getOutput();
      throw FFmpegExportException(log ?? 'FFmpeg failed');
    }
  }

  Future<String> muxAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    int audioBitrate = 192,
  }) async {
    final videoFile = File(videoPath);
    final audioFile = File(audioPath);

    if (!await videoFile.exists()) {
      throw FFmpegExportException('Video file not found: $videoPath');
    }
    if (!await audioFile.exists()) {
      throw FFmpegExportException('Audio file not found: $audioPath');
    }

    String quote(String path) => "'${path.replaceAll("'", "'\\''")}'";

    final cmd =
        '-i ${quote(videoPath)} '
        '-i ${quote(audioPath)} '
        '-c:v copy '
        '-c:a aac '
        '-b:a ${audioBitrate}k '
        '-map 0:v '
        '-map 1:a '
        '-shortest '
        '${quote(outputPath)}';

    debugPrint('FFmpeg mux cmd: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outputPath;
    } else {
      final log = await session.getOutput();
      throw FFmpegExportException('FFmpeg mux audio failed (rc=$rc): $log');
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
