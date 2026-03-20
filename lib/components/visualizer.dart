import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/models.dart'; // 引入你的設定檔
import 'audio_math.dart'; // 引入你的數學工具

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
  List<double> _currentHeights = [];
  double _lastTime = 0.0;
  List<dynamic> _bands = [];

  @override
  void initState() {
    super.initState();
    _initHeights();
    _initBands();

    // 啟動 Ticker 代替 requestAnimationFrame
    _ticker = createTicker(_render)..start();
  }

  void _initHeights() {
    _currentHeights = List<double>.filled(widget.settings.barCount, 0.0);
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (int i = 0; i < widget.settings.barCount; i++) {
      final val = sin(i * 0.5 + time) * 0.05 + 0.1;
      _currentHeights[i] = val * widget.settings.barHeightMultiplier;
    }
  }

  void _initBands() {
    _bands = generateFrequencyBands(
      widget.settings.barCount,
      44100.0, // SoLoud 內部常見 sample rate
      256, // SoLoud getFft 通常回傳長度 256 的陣列
      widget.settings.minFreq,
      widget.settings.maxFreq,
    );
  }

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.barCount != widget.settings.barCount) {
      _initHeights();
      _initBands();
    }
  }

  // 對應原本的 render(time) 函數
  void _render(Duration elapsed) {
    final double time = elapsed.inMilliseconds / 1000.0;
    double dt = time - _lastTime;
    if (dt > 0.1) dt = 0.1; // 限制最大 dt (Math.min(0.1, ...))
    _lastTime = time;

    if (widget.isPlaying) {
      // 1. 從 flutter_soloud 獲取 FFT 數據 (256 個頻段的能量值)
      // 注意：根據 SoLoud 版本，可能是 getAudioTexture2D 或是 getFft
      final fftData = SoLoud.instance.getAudioTexture2D();
      // 若你的版本是 List<double> getFft()，則換成對應方法

      // 2. 利用 audioMath 計算新的高度
      _currentHeights = calculateBarHeights(
        fftData.cast<double>(), // 轉型確保型別正確
        _bands,
        widget.settings,
        _currentHeights,
      );
    } else {
      // 待機動畫邏輯 (Idle animation)
      final double idleSpeed = dt * 10;
      for (int i = 0; i < widget.settings.barCount; i++) {
        final val = sin(i * 0.5 + time) * 0.05 + 0.1;
        final target = val * widget.settings.barHeightMultiplier;
        _currentHeights[i] += (target - _currentHeights[i]) * idleSpeed;
      }
    }

    // 觸發重新繪製 (對應呼叫 drawFrame 的時機)
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black, // 對應原本的 ctx.fillStyle = "#000"
      child: CustomPaint(
        // 把計算好的高度與設定傳給 Painter
        painter: VisualizerPainter(_currentHeights, widget.settings),
      ),
    );
  }
}

// 這裡對應你原本的 drawFrame 邏輯
class VisualizerPainter extends CustomPainter {
  final List<double> heights;
  final VisualizerSettings settings;

  VisualizerPainter(this.heights, this.settings);

  @override
  void paint(Canvas canvas, Size size) {
    // 【drawFrame 的部分再說】
    // 這裡留空或畫簡單的柱狀體，等你下一步指示
    final paint = Paint()..color = Colors.white;
    final barWidth = size.width / heights.length;

    for (int i = 0; i < heights.length; i++) {
      final h = heights[i]; // 假設已是實際像素高度或比例
      // 簡單的 placeholder 繪製
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth - 1, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    // 為了效能，每次 setState 都重繪
    return true;
  }
}
