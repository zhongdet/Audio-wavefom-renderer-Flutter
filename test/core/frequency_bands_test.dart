import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/frequency_bands.dart';
import 'package:flutter_application_1/core/constants.dart';

void main() {
  test('generateFrequencyBands returns correct number of bands', () {
    final bands = generateFrequencyBands(64, 44100);
    expect(bands.length, 64);
  });

  test('all bands have end > start', () {
    final bands = generateFrequencyBands(64, 44100);
    for (final (start, end) in bands) {
      expect(end, greaterThan(start), reason: 'end must be greater than start');
    }
  });

  test('all start values are within valid range', () {
    final bands = generateFrequencyBands(64, 44100);
    final maxBin = kFftSize ~/ 2;
    for (final (start, end) in bands) {
      expect(start, inInclusiveRange(0, maxBin - 1));
      expect(end, inInclusiveRange(1, maxBin));
    }
  });

  test('first band covers low frequencies near minFreq', () {
    final bands = generateFrequencyBands(64, 44100);
    final (start, _) = bands.first;
    // First band should start near bin 0 (20 Hz at 44100 Hz sample rate with 4096 FFT)
    expect(start, lessThanOrEqualTo(2));
  });

  test('last band ends near kMaxFreq bin', () {
    final bands = generateFrequencyBands(64, 44100);
    final (_, end) = bands.last;
    // kMaxFreq = 16000 Hz, bin = 16000 * 4096 / 44100 ≈ 1483
    final expectedBin = (kMaxFreq * kFftSize / 44100).round();
    expect(end, closeTo(expectedBin, 10));
  });

  test('bands are monotonically increasing', () {
    final bands = generateFrequencyBands(64, 44100);
    for (int i = 1; i < bands.length; i++) {
      final (prevStart, prevEnd) = bands[i - 1];
      final (currStart, currEnd) = bands[i];
      expect(currStart, greaterThanOrEqualTo(prevStart));
      expect(currEnd, greaterThanOrEqualTo(prevEnd));
    }
  });
}
