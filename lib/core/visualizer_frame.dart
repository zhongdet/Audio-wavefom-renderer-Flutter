import 'dart:typed_data';
import 'constants.dart';

class VisualizerFrame {
  final Float64List magnitudes;
  final Float32List waveformSamples;

  VisualizerFrame({required this.magnitudes, required this.waveformSamples})
    : assert(magnitudes.length == kFftSize ~/ 2),
      assert(waveformSamples.length == kFftSize);
}
