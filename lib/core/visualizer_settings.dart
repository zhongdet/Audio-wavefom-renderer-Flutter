class VisualizerSettings {
  final int barCount;
  final double attack;
  final double decay;
  final double contrast;
  final double barHeightMultiplier;
  final double softCeilingThreshold;
  final double softCeilingStrength;
  final int referenceFps;

  const VisualizerSettings({
    this.barCount = 64,
    this.attack = 0.05,
    this.decay = 0.92,
    this.contrast = 1.2,
    this.barHeightMultiplier = 1.0,
    this.softCeilingThreshold = 0.7,
    this.softCeilingStrength = 2.0,
    this.referenceFps = 60,
  });

  VisualizerSettings copyWith({
    int? barCount,
    double? attack,
    double? decay,
    double? contrast,
    double? barHeightMultiplier,
    double? softCeilingThreshold,
    double? softCeilingStrength,
    int? referenceFps,
  }) {
    return VisualizerSettings(
      barCount: barCount ?? this.barCount,
      attack: attack ?? this.attack,
      decay: decay ?? this.decay,
      contrast: contrast ?? this.contrast,
      barHeightMultiplier: barHeightMultiplier ?? this.barHeightMultiplier,
      softCeilingThreshold: softCeilingThreshold ?? this.softCeilingThreshold,
      softCeilingStrength: softCeilingStrength ?? this.softCeilingStrength,
      referenceFps: referenceFps ?? this.referenceFps,
    );
  }
}
