import 'dart:math';
import 'constants.dart';

List<(int, int)> generateFrequencyBands(
  int barCount,
  int sampleRate, {
  int fftSize = kFftSize,
  double minFreq = kMinFreq,
  double maxFreq = kMaxFreq,
}) {
  final bands = <(int, int)>[];

  for (int i = 0; i < barCount; i++) {
    final f0 = minFreq * pow(maxFreq / minFreq, i / barCount);
    final f1 = minFreq * pow(maxFreq / minFreq, (i + 1) / barCount);

    final b0 = (f0 * fftSize / sampleRate).floor();
    final b1 = max(b0 + 1, (f1 * fftSize / sampleRate).floor());

    final start = b0.clamp(0, (fftSize ~/ 2) - 1);
    final end = b1.clamp(start + 1, fftSize ~/ 2);

    bands.add((start, end));
  }

  return bands;
}
