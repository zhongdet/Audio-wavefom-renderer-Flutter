import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/models.dart';
import '../utils/audio_math.dart';

class Visualizer extends StatefulWidget {
  final VisualizerSettings settings;
  final bool isPlaying;

  const Visualizer({
    super.key,
    required this.settings,
    required this.isPlaying,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late AudioData _audioData; // 最新版本使用的資料結構
  List<double> _currentHeights = [];
  double _lastTime = 0.0;
  List<FrequencyBand> _bands = [];

  @override
  void initState() {
    super.initState();
    _audioData = AudioData(); // 初始化 AudioData
    _initHeights();
    _initBands();
    _setVisualization(true);
    _ticker = createTicker(_render)..start();
  }

  void _initHeights() {
    _currentHeights = List<double>.filled(widget.settings.barCount, 0.0);
  }

  void _initBands() {
    _bands = generateFrequencyBands(widget.settings.barCount, 44100);
  }

  void _setVisualization(bool enabled) {
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.setVisualizationEnabled(enabled);
    }
  }

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.barCount != widget.settings.barCount) {
      _initHeights();
      _initBands();
    }
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _setVisualization(true);
    }
  }

  void _render(Duration elapsed) {
    if (!mounted) return;

    final double time = elapsed.inMilliseconds / 1000.0;
    double dt = (time - _lastTime).clamp(0.0, 0.1);
    _lastTime = time;

    final soloud = SoLoud.instance;

    if (widget.isPlaying && soloud.isInitialized) {
      // 在最新版本中，使用 getAudioData 填充 _audioData
      // 這通常是一個 extension 方法，定義在 package 的內部擴展中
      soloud.getAudioData(_audioData);

      // 獲取 FFT 數據 (通常是 _audioData.samples 的前 256 位)
      // 注意：具體屬性名稱可能依版本微調為 samples 或 fft
      final magnitudes = Float32List.sublistView(_audioData.samples, 0, 256);

      _currentHeights = calculateBarHeights(
        magnitudes,
        _bands,
        widget.settings,
        _currentHeights,
        dt,
      );
    } else {
      _applyIdleAnimation(time, dt);
    }

    setState(() {});
  }

  void _applyIdleAnimation(double time, double dt) {
    final double idleSpeed = dt * 10;
    for (int i = 0; i < widget.settings.barCount; i++) {
      final val = sin(i * 0.5 + time) * 0.05 + 0.1;
      final target = val * widget.settings.barHeightMultiplier;
      _currentHeights[i] += (target - _currentHeights[i]) * idleSpeed;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audioData.dispose(); // 記得釋放 AudioData 資源
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: VisualizerPainter(
        heights: _currentHeights,
        settings: widget.settings,
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  final List<double> heights;
  final VisualizerSettings settings;
  VisualizerPainter({required this.heights, required this.settings});

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const double gap = 2.0;
    final double barWidth =
        (size.width - (heights.length - 1) * gap) / heights.length;

    for (int i = 0; i < heights.length; i++) {
      final double h = heights[i].clamp(0.0, size.height);
      final rect = Rect.fromLTWH(
        i * (barWidth + gap),
        size.height - h,
        barWidth,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) => true;
}
