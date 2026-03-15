import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../models/visualizer_settings.dart';

class VisualizerSettingsNotifier extends Notifier<VisualizerSettings> {
  @override
  VisualizerSettings build() {
    return const VisualizerSettings();
  }

  void update(
    VisualizerSettings Function(VisualizerSettings current) updateFn,
  ) {
    state = updateFn(state);
  }

  void patch({
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
    state = state.updateWith(
      barCount: barCount,
      barWidth: barWidth,
      barHeightMultiplier: barHeightMultiplier,
      cornerRadius: cornerRadius,
      totalWidth: totalWidth,
      spacing: spacing,
      backgroundColor: backgroundColor,
      positiveHeightScale: positiveHeightScale,
      negativeHeightScale: negativeHeightScale,
      positiveColor: positiveColor,
      negativeColor: negativeColor,
      decay: decay,
      attack: attack,
      contrast: contrast,
      yOffset: yOffset,
      renderFps: renderFps,
      encoder: encoder,
      softCeilingThreshold: softCeilingThreshold,
      softCeilingStrength: softCeilingStrength,
      referenceFps: referenceFps,
      minFreq: minFreq,
      maxFreq: maxFreq,
    );
  }
}

final visualizerSettingsProvider =
    NotifierProvider<VisualizerSettingsNotifier, VisualizerSettings>(
      VisualizerSettingsNotifier.new,
    );
