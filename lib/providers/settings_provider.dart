import 'package:flutter/widgets.dart';

enum AudioEncoder { webcodecsHw, webcodecsSw, ffmpeg }

class VisualizerSettings extends ChangeNotifier {
  int _barCount = 64;
  double _barWidth = 2.0;
  double _barHeightMultiplier = 1.0;
  double _cornerRadius = 0.0;
  double _totalWidth = 300.0;
  double _spacing = 1.0;
  Color _backgroundColor = const Color(0xFF000000);
  double _positiveHeightScale = 1.0;
  double _negativeHeightScale = 1.0;
  Color _positiveColor = const Color.fromARGB(255, 255, 255, 255);
  Color _negativeColor = const Color.fromARGB(255, 72, 72, 72);
  double _decay = 0.1;
  double _attack = 0.1;
  double _contrast = 1.0;
  double _yOffset = 0.0;
  int _renderFps = 60;
  AudioEncoder _encoder = AudioEncoder.webcodecsHw;
  double _softCeilingThreshold = 0.9;
  double _softCeilingStrength = 0.5;
  int _referenceFps = 60;
  double _minFreq = 20.0;
  double _maxFreq = 20000.0;

  int get barCount => _barCount;
  double get barWidth => _barWidth;
  double get barHeightMultiplier => _barHeightMultiplier;
  double get cornerRadius => _cornerRadius;
  double get totalWidth => _totalWidth;
  double get spacing => _spacing;
  Color get backgroundColor => _backgroundColor;
  double get positiveHeightScale => _positiveHeightScale;
  double get negativeHeightScale => _negativeHeightScale;
  Color get positiveColor => _positiveColor;
  Color get negativeColor => _negativeColor;
  double get decay => _decay;
  double get attack => _attack;
  double get contrast => _contrast;
  double get yOffset => _yOffset;
  int get renderFps => _renderFps;
  AudioEncoder get encoder => _encoder;
  double get softCeilingThreshold => _softCeilingThreshold;
  double get softCeilingStrength => _softCeilingStrength;
  int get referenceFps => _referenceFps;
  double get minFreq => _minFreq;
  double get maxFreq => _maxFreq;

  void updateSettings({
    int? barCount,
    double? barWidth,
    double? barHeightMultiplier,
    double? cornerRadius,
    double? totalWidth,
    double? spacing,
    Color? color,
    Color? backgroundColor,
    double? positiveHeightScale,
    double? negativeHeightScale,
    Color? positiveColor,
    Color? negativeColor,
    double? decay,
    double? attack,
    double? contrast,
    double? yOffset,
    int? renderFps,
    AudioEncoder? encoder,
    double? softCeilingThreshold,
    double? softCeilingStrength,
    int? referenceFps,
    double? minFreq,
    double? maxFreq,
  }) {
    if (barCount != null) _barCount = barCount;
    if (barWidth != null) _barWidth = barWidth;
    if (barHeightMultiplier != null) _barHeightMultiplier = barHeightMultiplier;
    if (cornerRadius != null) _cornerRadius = cornerRadius;
    if (totalWidth != null) _totalWidth = totalWidth;
    if (spacing != null) _spacing = spacing;
    if (backgroundColor != null) _backgroundColor = backgroundColor;
    if (positiveHeightScale != null) _positiveHeightScale = positiveHeightScale;
    if (negativeHeightScale != null) _negativeHeightScale = negativeHeightScale;
    if (positiveColor != null) _positiveColor = positiveColor;
    if (negativeColor != null) _negativeColor = negativeColor;
    if (decay != null) _decay = decay;
    if (attack != null) _attack = attack;
    if (contrast != null) _contrast = contrast;
    if (yOffset != null) _yOffset = yOffset;
    if (renderFps != null) _renderFps = renderFps;
    if (encoder != null) _encoder = encoder;
    if (softCeilingThreshold != null)
      _softCeilingThreshold = softCeilingThreshold;
    if (softCeilingStrength != null) _softCeilingStrength = softCeilingStrength;
    if (referenceFps != null) _referenceFps = referenceFps;
    if (minFreq != null) _minFreq = minFreq;
    if (maxFreq != null) _maxFreq = maxFreq;

    notifyListeners();
  }
}
