import 'package:flutter/widgets.dart';

enum AudioEncoder { webcodecHw, webcodecSw, ffmpeg }

@immutable
class VisualizerSettings {
  final int barCount;
  final double barWidth;
  final double barHeightMultiplier;
  final double cornerRadius;
  final double totalWidth;
  final double spacing;
  final Color backgroundColor;
  final double positiveHeightScale;
  final double negativeHeightScale;
  final Color positiveColor;
  final Color negativeColor;
  final double decay;
  final double attack;
  final double contrast;
  final double yOffset;
  final int renderFps;
  final AudioEncoder encoder;
  final double softCeilingThreshold;
  final double softCeilingStrength;
  final int referenceFps;
  final double minFreq;
  final double maxFreq;

  const VisualizerSettings({
    this.barCount = 64,
    this.barWidth = 2.0,
    this.barHeightMultiplier = 1.0,
    this.cornerRadius = 0.0,
    this.totalWidth = 300.0,
    this.spacing = 1.0,
    this.backgroundColor = const Color(0xFF000000),
    this.positiveHeightScale = 1.0,
    this.negativeHeightScale = 1.0,
    this.positiveColor = const Color.fromARGB(255, 255, 255, 255),
    this.negativeColor = const Color.fromARGB(255, 72, 72, 72),
    this.decay = 0.1,
    this.attack = 0.1,
    this.contrast = 1.0,
    this.yOffset = 0.0,
    this.renderFps = 60,
    this.encoder = AudioEncoder.webcodecHw,
    this.softCeilingThreshold = 0.9,
    this.softCeilingStrength = 0.5,
    this.referenceFps = 60,
    this.minFreq = 20.0,
    this.maxFreq = 20000.0,
  });

  VisualizerSettings updateWith({
    int? barCount,
    double? barWidth,
    double? barHeightMultiplier,
    double? cornerRadius,
    double? totalWidth,
    double? spacing,
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
    return VisualizerSettings(
      barCount: barCount ?? this.barCount,
      barWidth: barWidth ?? this.barWidth,
      barHeightMultiplier: barHeightMultiplier ?? this.barHeightMultiplier,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      totalWidth: totalWidth ?? this.totalWidth,
      spacing: spacing ?? this.spacing,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      positiveHeightScale: positiveHeightScale ?? this.positiveHeightScale,
      negativeHeightScale: negativeHeightScale ?? this.negativeHeightScale,
      positiveColor: positiveColor ?? this.positiveColor,
      negativeColor: negativeColor ?? this.negativeColor,
      decay: decay ?? this.decay,
      attack: attack ?? this.attack,
      contrast: contrast ?? this.contrast,
      yOffset: yOffset ?? this.yOffset,
      renderFps: renderFps ?? this.renderFps,
      encoder: encoder ?? this.encoder,
      softCeilingThreshold: softCeilingThreshold ?? this.softCeilingThreshold,
      softCeilingStrength: softCeilingStrength ?? this.softCeilingStrength,
      referenceFps: referenceFps ?? this.referenceFps,
      minFreq: minFreq ?? this.minFreq,
      maxFreq: maxFreq ?? this.maxFreq,
    );
  }
}
