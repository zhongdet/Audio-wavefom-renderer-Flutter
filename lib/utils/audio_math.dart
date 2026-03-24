import 'dart:math' as math;
import 'dart:typed_data';
import '../models//models.dart';

// SoLoud 固定輸出 256 個 FFT 頻段，這對應於底層 512 size 的 FFT 運算
const int SOLOUD_FFT_BINS = 256;
const int SOLOUD_FFT_SIZE = 512;
const double MIN_FREQ = 20.0;
const double MAX_FREQ = 16000.0;

class FrequencyBand {
  final int start;
  final int end;

  FrequencyBand({required this.start, required this.end});
}

List<FrequencyBand> generateFrequencyBands(
  int barCount,
  int sampleRate, {
  int fftSize = SOLOUD_FFT_SIZE,
  double minFreq = MIN_FREQ,
  double maxFreq = MAX_FREQ,
}) {
  final List<FrequencyBand> bands = [];
  for (int i = 0; i < barCount; i++) {
    // 使用對數分佈來切割頻率 (Logarithmic scale)，讓低頻有更多細節
    final f0 = minFreq * math.pow(maxFreq / minFreq, i / barCount);
    final f1 = minFreq * math.pow(maxFreq / minFreq, (i + 1) / barCount);

    final b0 = ((f0 * fftSize) / sampleRate).floor();
    final b1 = math.max(b0 + 1, ((f1 * fftSize) / sampleRate).floor());

    // 加上 math.min 安全鎖，確保索引不會超出 SoLoud 的 256 個 bins 限制
    bands.add(
      FrequencyBand(
        start: math.min(b0, SOLOUD_FFT_BINS - 1),
        end: math.min(b1, SOLOUD_FFT_BINS),
      ),
    );
  }
  return bands;
}

final Stopwatch _stopwatch = Stopwatch()..start();
double _lastBarHeightsCall = _stopwatch.elapsedMicroseconds / 1000.0;

/// 計算平滑後的柱狀條高度
/// [magnitudes] 是由 SoLoud 直接提供長度為 256 的 FFT 強度陣列
List<double> calculateBarHeights(
  Float32List magnitudes,
  List<FrequencyBand> bands,
  VisualizerSettings settings,
  List<double> currentHeights, [
  double? dt,
]) {
  final newHeights = List<double>.from(currentHeights);

  if (dt == null) {
    final now = _stopwatch.elapsedMicroseconds / 1000.0;
    dt = (now - _lastBarHeightsCall) / 1000.0;
    _lastBarHeightsCall = now;
  }
  if (dt <= 0) dt = 1 / 60.0;

  final dtRatio = dt / (1 / (settings.referenceFps ?? 60.0));
  final attack =
      1.0 - math.pow(1.0 - (settings.attack ?? 0.05), dtRatio).toDouble();
  final decay = math.pow(settings.decay ?? 0.92, dtRatio).toDouble();
  final contrast = settings.contrast ?? 1.2;

  for (int b = 0; b < settings.barCount; b++) {
    final start = bands[b].start;
    final end = bands[b].end;
    double maxMag = 0.0;

    // 直接從 SoLoud 提供的 magnitudes 陣列取值，省略了算平方根的過程
    for (int bin = start; bin < end; bin++) {
      final mag = magnitudes[bin];
      if (mag > maxMag) maxMag = mag;
    }

    // 計算目標高度
    // 注意：SoLoud 取出的值域可能與原本 Web 端不同，如果發現太矮或太高，可以微調 0.007 這個常數
    double target =
        math.pow(maxMag, contrast).toDouble() *
        0.007 *
        settings.barHeightMultiplier;
    target = math.max(0.0, target);

    // Soft Ceiling (軟限制器，避免破音時柱子衝破畫面)
    final threshold = settings.softCeilingThreshold ?? 0.7;
    final strength = settings.softCeilingStrength ?? 2.0;
    if (target > threshold) {
      final excess = target - threshold;
      final compressedExcess = (1.0 - math.exp(-excess * strength)) / strength;
      target = threshold + compressedExcess;
    }

    // 應用 Attack (起音) 與 Decay (衰減) 讓動畫有彈性質感
    if (target > newHeights[b]) {
      newHeights[b] += (target - newHeights[b]) * attack;
    } else {
      double nextValue = newHeights[b] * decay;

      const maxDropRatio = 1.0;
      if (newHeights[b] - nextValue > newHeights[b] * maxDropRatio) {
        nextValue = newHeights[b] * (1.0 - maxDropRatio);
      }

      newHeights[b] = nextValue;
    }
    newHeights[b] = math.max(0.0, newHeights[b]);
  }
  return newHeights;
}
