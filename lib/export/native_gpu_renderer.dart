import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeGpuRenderer {
  static const _channel = MethodChannel('com.example/gpu_renderer');
  static const _progressChannel = EventChannel('com.example/export_progress');

  StreamSubscription? _progressSub;

  Future<String> startExport({
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    required int backgroundColor,
    required int barCount,
    required double barWidth,
    required double barSpacing,
    required double cornerRadius,
    required int barColorArgb,
    required Float64List frameHeights,
  }) async {
    final args = <String, dynamic>{
      'outputPath': outputPath,
      'width': width,
      'height': height,
      'fps': fps,
      'backgroundColor': backgroundColor,
      'barCount': barCount,
      'barWidth': barWidth,
      'barSpacing': barSpacing,
      'cornerRadius': cornerRadius,
      'barColorArgb': barColorArgb,
      'frameHeights': frameHeights,
    };

    return await _channel.invokeMethod<String>('startExport', args) ?? '';
  }

  Stream<double> get progress {
    return _progressChannel
        .receiveBroadcastStream()
        .map((event) => (event as num).toDouble());
  }

  static Future<void> cancelCurrentExport() async {
    await _channel.invokeMethod('cancelExport');
  }

  Future<void> cancelExport() async {
    await _channel.invokeMethod('cancelExport');
  }

  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }

  void disposeProgress() {
    _progressSub?.cancel();
    _progressSub = null;
  }
}
