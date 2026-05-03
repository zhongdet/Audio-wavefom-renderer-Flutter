import 'dart:typed_data';
import 'constants.dart';

class VisualizerFrame {
  final Float64List magnitudes;

  VisualizerFrame({required this.magnitudes})
    : assert(magnitudes.length == kFftSize ~/ 2);
}
